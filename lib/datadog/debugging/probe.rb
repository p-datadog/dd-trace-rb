module Datadog
  module Debugging
    # @api private
    class Probe

      def self.from_remote_config(config)
        new(
          id: config.fetch('id'),
          type: config.fetch('type'),
        )
      end

      def initialize(id:, type:)
        @id = id
        @type = type
      end

      attr_reader :id
      attr_reader :type
    end
  end
end
