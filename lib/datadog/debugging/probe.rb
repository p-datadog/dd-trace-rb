module Datadog
  module Debugging
    # @api private
    class Probe

      def self.from_remote_config(config)
        new(
          id: config.fetch('id'),
          type: config.fetch('type'),
          file: config['where']&.[]('sourceFile'),
          # Sometimes lines are received as an array of nil
          line_nos: config['where']&.[]('lines').compact.map(&:to_i),
          template: config['template'],
        )
      end

      def initialize(id:, type:,
        file: nil, line_nos: nil, module_name: nil, function_name: nil,
        template: nil
      )
        @id = id
        @type = type
        @file = file
        @line_nos = line_nos
        @module_name = module_name
        @function_name = function_name
        @template = template
      end

      attr_reader :id
      attr_reader :type
      attr_reader :file
      attr_reader :line_nos
      attr_reader :module_name
      attr_reader :function_name
    end
  end
end
