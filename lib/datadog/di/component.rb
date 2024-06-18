# frozen_string_literal: true

module Datadog
  module DI
    # Component for DI.
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
        @remote_processor = RemoteProcessor.new(hook_manager)
      end

      attr_reader :settings
      attr_reader :agent_settings
      attr_reader :hook_manager
      attr_reader :remote_processor

      def shutdown!(replacement = nil)
      end
    end
  end
end
