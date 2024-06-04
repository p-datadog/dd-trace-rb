# frozen_string_literal: true

module Datadog
  module DI
    # Core-pluggable component for DI
    class Component
      class << self
        def build(settings, agent_settings)
          return unless settings.respond_to?(:debugging) && settings.debugging.enabled

          new(settings, agent_settings)
        end
      end

      def initialize(settings, agent_settings)
        @settings = settings
        @agent_settings = agent_settings
      end

      attr_reader :settings
      attr_reader :agent_settings

      def shutdown!(replacement = nil)
      end

      def add_probe_from_remote(config)
        where = config.fetch('where')
        if where.key?('sourceFile')
          file = where.fetch('sourceFile')
          lines = where.fetch('lines')

          lines.each do |line|
            line = Integer(line)
            Hook.hook_line(file, line) do
              puts 'hook executed'
            end
          end
        end
      end
    end
  end
end
