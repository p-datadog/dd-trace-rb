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
          line_nos: config['where']&.[]('lines')&.compact&.map(&:to_i),
          type_name: config['where']&.[]('typeName'),
          method_name: config['where']&.[]('methodName'),
          template: config['template'],
        )
      end

      def initialize(id:, type:,
        file: nil, line_nos: nil, type_name: nil, method_name: nil,
        template: nil
      )
        @id = id
        @type = type
        @file = file
        @line_nos = line_nos
        @type_name = type_name
        @method_name = method_name
        @template = template
      end

      attr_reader :id
      attr_reader :type
      attr_reader :file
      attr_reader :line_nos
      attr_reader :type_name
      attr_reader :method_name
      attr_reader :template

      def line?
        line_nos && !line_nos.empty?
      end

      def method?
        type_name && method_name
      end
    end
  end
end
