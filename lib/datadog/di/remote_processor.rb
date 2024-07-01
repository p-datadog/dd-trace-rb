# frozen_string_literal: true

module Datadog
  module DI
    # @api private
    class RemoteProcessor
      def initialize(hook_manager, defined_probes, installed_probes)
        @hook_manager = hook_manager
        @defined_probes = defined_probes
        @installed_probes = installed_probes
      end

      attr_reader :hook_manager
      attr_reader :defined_probes
      attr_reader :installed_probes

      # config is one probe info
      def process(config)
        probe = ProbeBuilder.build_from_remote_config(config)
        defined_probes[probe.id] = probe
        ProbeNotifier.notify_received(probe)

        if probe.line?
          hook_manager.hook_line(probe.file, probe.line_nos.first) do |tp|
            puts '*** line probe executed ***'
            ProbeNotifier.notify_emitting(probe)
            ProbeNotifier.notify_executed(probe, tracepoint: tp, callers: caller)
          end
        elsif probe.method?
          hook_manager.hook_method(probe.type_name, probe.method_name) do |**opts|
            puts "*** method probe executed: #{opts} ***"
            #byebug
            ProbeNotifier.notify_emitting(probe)
            ProbeNotifier.notify_executed(probe, **opts)
          end
        else
          warn "Not a line or method probe: #{probe.id}"
          return
        end

        installed_probes[probe.id] = probe
        ProbeNotifier.notify_installed(probe)
      rescue => exc
        # Silence all exceptions?
        warn "Error processing probe configuration: #{exc.class}: #{exc}"
      end
    end
  end
end
