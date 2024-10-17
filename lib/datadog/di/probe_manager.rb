# frozen_string_literal: true

module Datadog
  module DI
    # Stores probes received from remote config (that we can parse, in other
    # wordrs, whose type/attributes we support), requests needed instrumentation
    # for the probes via Instrumenter, and stores pending probes (those which
    # haven't yet been instrumented successfully due to their targets not
    # existing) and failed probes (where we are certain the target will not
    # ever be loaded, or otherwise become valid).
    #
    # @api private
    class ProbeManager
      def initialize(settings, instrumenter, probe_notification_builder, probe_notifier_worker)
        @settings = settings
        @instrumenter = instrumenter
        @probe_notification_builder = probe_notification_builder
        @probe_notifier_worker = probe_notifier_worker
        @installed_probes = {}
        @pending_probes = {}

        @definition_trace_point = TracePoint.trace(:end) do |tp|
          install_pending_method_probes(tp.self)
        end
      end

      # TODO test that close is called during component teardown and
      # the trace point is cleared
      def close
        definition_trace_point.disable
        clear_hooks
      end

      def clear_hooks
        pending_probes.clear
        installed_probes.each do |probe_id, probe|
          instrumenter.unhook(probe)
        end
        installed_probes.clear
      end

      attr_reader :settings
      attr_reader :instrumenter
      attr_reader :probe_notification_builder
      attr_reader :probe_notifier_worker
      attr_reader :installed_probes
      attr_reader :pending_probes

      # config is one probe info
      def add_probe(probe)
        # TODO lock here?
        begin
          instrumenter.hook(probe, &method(:probe_executed_callback))

          installed_probes[probe.id] = probe
          payload = probe_notification_builder.build_installed(probe)
          probe_notifier_worker.add_status(payload)
          # The probe would only be in the pending probes list if it was
          # previously attempted to be installed and the target was not loaded.
          # Always remove from pending list here because it makes the
          # API smaller and shouldn't cause any actual problems.
          pending_probes.delete(probe.id)
        rescue Error::DITargetNotDefined => exc
          pending_probes[probe.id] = probe
        end
      rescue => exc
        raise if settings.dynamic_instrumentation.propagate_all_exceptions
        # Silence all exceptions?
        # TODO should we propagate here and rescue upstream?
        warn "Error processing probe configuration: #{exc.class}: #{exc}"
      end

      def remove_other_probes(probe_ids)
        pending_probes.values.each do |probe|
          unless probe_ids.include?(probe.id)
            pending_probes.delete(probe.id)
          end
        end
        installed_probes.values.each do |probe|
          unless probe_ids.include?(probe.id)
            begin
              instrumenter.unhook(probe)
              # Only remove the probe from installed list if it was
              # successfully de-instrumented. Active probes do incur overhead
              # for the running application, and if the error is ephemeral
              # we want to try removing the probe again at the next opportunity.
              #
              # TODO give up after some time?
              installed_probes.delete(probe.id)
            rescue => exc
              raise if settings.dynamic_instrumentation.propagate_all_exceptions
              # Silence all exceptions?
              # TODO should we propagate here and rescue upstream?
              warn "Error removing probe #{probe.id}: #{exc.class}: #{exc}"
            end
          end
        end
      end

      private def install_pending_method_probes(cls)
        # TODO search more efficiently than linearly
        pending_probes.each do |probe_id, probe|
          if probe.method?
            # TODO move this stringification elsewhere
            if probe.type_name == cls.name
              # TODO is it OK to hook from trace point handler?
              # TODO the class is now defined, but can hooking still fail?
              # TODO pass rate_limiter here, need to get it from somewhere
              hook_method(probe.type_name, probe.method_name,
                rate_limiter: probe.rate_limiter, &instance_method(:probe_executed_callback))
              pending_probes.delete(probe.id)
              break
            end
          end
        end
      end

      def install_pending_line_probes(file)
        pending_probes.values.each do |probe|
          if probe.line?
            if probe.file_matches?(file)
              add_probe(probe)
            end
          end
        end
      end

      def probe_executed_callback(probe:, **opts)
        # TODO notify emitting once only
        payload = probe_notification_builder.build_emitting(probe)
        probe_notifier_worker.add_status(payload)
        payload = probe_notification_builder.build_executed(probe, **opts)
        probe_notifier_worker.add_snapshot(payload)
      end

      # Class/module definition trace point (:end type).
      # Used to install hooks when the target classes/modules aren't yet
      # defined when the hook request is received.
      attr_reader :definition_trace_point
    end
  end
end
