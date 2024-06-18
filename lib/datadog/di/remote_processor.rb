# frozen_string_literal: true

module Datadog
  module DI
    class RemoteProcessor
      def initialize(hook_manager)
        @hook_manager = hook_manager
      end

      attr_reader :hook_manager

      def process(config)
        # config is one probe info
        puts '--- got probe:'
        pp config

        probe = ProbeBuilder.build_from_remote_config(config)
        ProbeNotifier.notify_received(probe)

        if probe.line?
          hook_manager.hook_line(probe.file, probe.line_nos.first) do |tp|
            puts '*** line probe executed ***'
            ProbeNotifier.notify_emitting(probe)
            ProbeNotifier.notify_executed(probe, tracepoint: tp, callers: caller)
          end

          INSTALLED_PROBES[probe.id] = probe
        elsif probe.method?
          hook_manager.hook_method(probe.type_name, probe.method_name) do |**opts|
            puts "*** method probe executed: #{opts} ***"
            #byebug
            ProbeNotifier.notify_emitting(probe)
            ProbeNotifier.notify_executed(probe, **opts)
          end
        else
          puts "Not a line or method probe"
        end

        ProbeNotifier.notify_installed(probe)

        component.add_probe_from_remote(config)
      end
    end
  end
end
