# frozen_string_literal: true

module Datadog
  module DI
    class CodeTracker
      def initialize
        @method_registry = Concurrent::Map.new
      end

      def start
        @compiled_trace_point = TracePoint.new(:script_compiled) do |tp|
          # Useful attributes of the trace point here:
          # .instruction_sequence
          # .method_id
          # .path
          # .eval_script
          #
          # For now just map the path to the instruction sequence.
          method_registry[tp.path] = tp.instruction_sequence
        end
        @compiled_trace_point.enable
      end

      private

      attr_reader :method_registry
    end
  end
end
