# frozen_string_literal: true

module Datadog
  module DI
    # Component for dynamic instrumentation.
    #
    # Only one instance of the Component should ever be active;
    # if configuration is changed, the old distance should be shut down
    # prior to the new instance being created.
    #
    # The Component instance stores all state related to DI, for example
    # which probes have been retrieved via remote config,
    # intalled tracepoints and so on. Component will clean up all
    # resources and installed tracepoints upon shutdown.
    class Component
      class << self
        def build(settings, agent_settings, logger, telemetry: nil)
          return unless settings.respond_to?(:dynamic_instrumentation) && settings.dynamic_instrumentation.enabled

          unless settings.respond_to?(:remote) && settings.remote.enabled
            logger.warn("di: dynamic instrumentation could not be enabled because Remote Configuration Management is not available. To enable Remote Configuration, see https://docs.datadoghq.com/agent/remote_config")
            return
          end

          return unless environment_supported?(settings, logger)

          new(settings, agent_settings, logger, code_tracker: DI.code_tracker, telemetry: telemetry).tap do |component|
            DI.add_current_component(component)
          end
        end

        # Checks whether the runtime environment is supported by
        # dynamic instrumentation. Currently we only require that, if Rails
        # is used, that Rails environment is not development because
        # DI does not currently support code unloading and reloading.
        def environment_supported?(settings, logger)
          # TODO add tests?
          unless settings.dynamic_instrumentation.internal.development
            if Datadog::Core::Environment::Execution.development?
              logger.warn("di: development environment detected; not enabling dynamic instrumentation")
              return false
            end
          end
          if RUBY_ENGINE != 'ruby'
            logger.warn("di: cannot enable dynamic instrumentation: MRI is required, but running on #{RUBY_ENGINE}")
            return false
          end
          if RUBY_VERSION < '2.6'
            logger.warn("di: cannot enable dynamic instrumentation: Ruby 2.6+ is required, but running on #{RUBY_VERSION}")
            return false
          end
          unless DI.respond_to?(:exception_message)
            logger.warn("di: cannot enable dynamic instrumentation: C extension is not available")
            return false
          end
          true
        end
      end

      def initialize(settings, agent_settings, logger, code_tracker: nil, telemetry: nil)
        @settings = settings
        @agent_settings = agent_settings
        logger = DI::Logger.new(settings, logger)
        @logger = logger
        @telemetry = telemetry
        @code_tracker = code_tracker
        @redactor = Redactor.new(settings)
        # Process-wide rate limiter (RFC: global rate limit).
        @global_rate_limiter = Datadog::Core::TokenBucket.new(
          settings.dynamic_instrumentation.global_rate_limit
        )
        # Atomic flag for the remote-config kill switch (RFC: kill switch).
        # Initially nil (meaning "no RC opinion yet"); flipped to true/false
        # when the RC dispatcher applies APM_TRACING lib_config.
        @rc_enabled = nil
        @rc_enabled_mutex = Mutex.new
        @serializer = Serializer.new(settings, redactor, telemetry: telemetry)
        @instrumenter = Instrumenter.new(settings, serializer, logger, code_tracker: code_tracker, telemetry: telemetry)
        @probe_repository = ProbeRepository.new
        @probe_notification_builder = ProbeNotificationBuilder.new(settings, serializer, telemetry: telemetry)
        @probe_notifier_worker = ProbeNotifierWorker.new(
          settings, logger,
          agent_settings: agent_settings,
          probe_repository: probe_repository,
          probe_notification_builder: probe_notification_builder,
          telemetry: telemetry,
        )
        @probe_manager = ProbeManager.new(
          settings, instrumenter, probe_notification_builder, probe_notifier_worker, logger, probe_repository,
          telemetry: telemetry,
        )
        @instrumenter.component = self
        probe_notifier_worker.start
        report_initial_runtime_state
      end

      attr_reader :settings
      attr_reader :agent_settings
      attr_reader :logger
      attr_reader :telemetry
      attr_reader :code_tracker
      attr_reader :instrumenter
      attr_reader :probe_repository
      attr_reader :probe_notifier_worker
      attr_reader :global_rate_limiter

      # Applies the remote-config kill switch.
      # +flag+ is the value of lib_config["dynamic_instrumentation_enabled"]:
      #   - true  -> RC explicitly enables
      #   - false -> RC explicitly disables
      #   - nil   -> RC removed the override (revert to local config)
      def apply_rc_enabled(flag)
        changed = false
        @rc_enabled_mutex.synchronize do
          changed = flag != @rc_enabled
          @rc_enabled = flag
        end
        report_runtime_state if changed
      end

      # Effective enabled state: local config AND not RC-disabled.
      def effective_enabled?
        return false unless settings.dynamic_instrumentation.enabled
        @rc_enabled_mutex.synchronize do
          @rc_enabled != false
        end
      end

      # Reason for the current effective state. Matches the RFC's
      # `debugger.di.enabled_reason` enum values.
      def enabled_reason
        unless settings.dynamic_instrumentation.enabled
          return 'localConfigDisabled'
        end
        @rc_enabled_mutex.synchronize do
          case @rc_enabled
          when false then 'remoteConfigDisabled'
          else 'enabled'
          end
        end
      end
      attr_reader :probe_notification_builder
      attr_reader :probe_manager
      attr_reader :redactor
      attr_reader :serializer

      # Shuts down dynamic instrumentation.
      #
      # Removes all code hooks and stops background threads.
      #
      # Does not clear out the code tracker, because it's only populated
      # by code when code is compiled and therefore, if the code tracker
      # was replaced by a new instance, the new instance of it wouldn't have
      # any of the already loaded code tracked.
      def shutdown!(replacement = nil)
        DI.remove_current_component(self)

        probe_manager.clear_hooks
        probe_manager.close
        probe_notifier_worker.stop
      end

      def parse_probe_spec_and_notify(probe_spec)
        probe = ProbeBuilder.build_from_remote_config(probe_spec)
      rescue => exc
        begin
          probe = Struct.new(:id).new(
            probe_spec['id'],
          )
          payload = probe_notification_builder.build_errored(probe, exc)
          probe_notifier_worker.add_status(payload)
        rescue => nested_exc
          logger.debug { "di: failed to build error notification: #{nested_exc.class}: #{nested_exc.message}" }
          telemetry&.report(nested_exc, description: 'Error building probe error notification')
          raise
        end

        raise
      else
        payload = probe_notification_builder.build_received(probe)
        probe_notifier_worker.add_status(payload, probe: probe)
        probe
      end

      # Emits the `probes.count` gauge for the current state of the
      # probe repository. Should be called from the probe-notifier worker
      # on its flush cadence.
      def emit_probes_count_gauge
        return unless telemetry

        # Aggregate by (event_type, probe_status).
        counts = Hash.new(0)
        probe_repository.each_installed do |probe|
          status = probe.enabled? ? Metrics::ProbeStatus::EMITTING : Metrics::ProbeStatus::BLOCKED
          counts[[Metrics.event_type_for_probe(probe), status]] += 1
        end
        probe_repository.each_pending do |probe|
          counts[[Metrics.event_type_for_probe(probe), Metrics::ProbeStatus::RECEIVED]] += 1
        end
        counts.each do |(event_type, status), count|
          Metrics.emit_probes_count(telemetry, count,
            event_type: event_type, probe_status: status)
        end
      end

      private

      def report_initial_runtime_state
        report_runtime_state
      end

      # Emits runtime telemetry mirroring the RFC's
      # `debugger.di.enabled` / `debugger.di.enabled_reason`.
      #
      # The RFC requires that these be reported at startup AND on RC
      # changes. dd-trace-rb's `client_configuration_change!` is the
      # closest existing primitive (a one-shot AppClientConfigurationChange
      # event) so we reuse it.
      def report_runtime_state
        return unless telemetry&.respond_to?(:client_configuration_change!)

        begin
          telemetry.client_configuration_change!([
            { name: 'debugger.di.enabled', value: effective_enabled? },
            { name: 'debugger.di.enabled_reason', value: enabled_reason },
          ])
        rescue => exc
          raise if settings.dynamic_instrumentation.internal.propagate_all_exceptions
          logger&.debug { "di: failed to emit runtime state telemetry: #{exc.class}: #{exc.message}" }
        end
      end
    end
  end
end
