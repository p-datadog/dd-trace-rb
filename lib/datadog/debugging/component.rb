# frozen_string_literal: true

module Datadog
  module Debugging
    # Core-pluggable component for Debugging
    class Component
      class << self
        def build(settings)
          return unless settings.respond_to?(:debugging) && settings.debugging.enabled

          new
        end
      end

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
