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
        def build(settings, agent_settings)
          return unless settings.respond_to?(:internal_dynamic_instrumentation) && settings.internal_dynamic_instrumentation.enabled

          new(settings, agent_settings)
        end
      end

      def initialize(settings, agent_settings)
        @settings = settings
        @agent_settings = agent_settings
        @hook_manager = HookManager.new
        @defined_probes = Concurrent::Map.new
        @installed_probes = Concurrent::Map.new
        @probe_notifier_worker = ProbeNotifierWorker.new(settings, agent_settings)
        probe_notifier_worker.start
        @remote_processor = RemoteProcessor.new(settings, hook_manager, defined_probes, installed_probes)
      end

      attr_reader :settings
      attr_reader :agent_settings
      attr_reader :hook_manager
      attr_reader :defined_probes
      attr_reader :installed_probes
      attr_reader :probe_notifier_worker
      attr_reader :remote_processor

      # Shuts down dynamic instrumentation.
      #
      # Removes all code hooks and stops background threads.
      #
      # Does not clear out the code tracker, because it's only populated
      # by code when code is compiled and therefore, if the code tracker
      # was replaced by a new instance, the new instance of it wouldn't have
      # any of the already loaded code tracked.
      def shutdown!(replacement = nil)
        hook_manager.clear_hooks
        probe_notifier_worker.stop
      end
    end
  end
end
