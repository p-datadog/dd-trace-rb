# frozen_string_literal: true

module Datadog
  module DI
    # Encapsulates probe information (as received via remote config)
    # and state (e.g. whether the probe was installed, or executed).
    #
    # @api private
    class Probe

      def initialize(id:, type:,
        file: nil, line_nos: nil, type_name: nil, method_name: nil,
        template: nil, capture_snapshot: false
      )
        @id = id
        @type = type
        @file = file
        @line_nos = line_nos
        @type_name = type_name
        @method_name = method_name
        @template = template
        @capture_snapshot = capture_snapshot
      end

      attr_reader :id
      attr_reader :type
      attr_reader :file
      attr_reader :line_nos
      attr_reader :type_name
      attr_reader :method_name
      attr_reader :template

      def capture_snapshot?
        @capture_snapshot
      end

      def line?
        !!(line_nos && !line_nos.empty?) && !method?
      end

      def method?
        !!(type_name && method_name)
      end

      def line_no
        if line_nos.length == 1
          line_nos.first
        else
          raise ArgumentError, "Multiple or missing line numbers: #{line_nos}"
        end
      end

      def location
        if method?
          "#{type_name}.#{method_name}"
        elsif line?
          "#{file}:#{line_no}"
        else
          raise Error::UnknownProbeType, 'Unhandled probe type: neither method nor line probe'
        end
      end
    end
  end
end
