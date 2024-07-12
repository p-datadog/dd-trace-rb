# frozen_string_literal: true

module Datadog
  module DI
    # Tracks loaded Ruby code by source file and maintains a map from
    # source file to the loaded code (instruction sequences).
    #
    # The loaded code is used to target line trace points when installing
    # line probes which dramatically improves efficiency of line trace points.
    class CodeTracker
      def initialize
        @method_registry = Concurrent::Map.new
      end

      def start
        @compiled_trace_point = TracePoint.new(:script_compiled) do |tp|
          # Useful attributes of the trace point here:
          # .instruction_sequence
          # .method_id
          # .path (refers to the code location that called the require/eval/etc.,
          #   not where the loaded code is; use .path on the instruction sequence
          #   to obtain the location of the compiled code)
          # .eval_script
          #
          # For now just map the path to the instruction sequence.
          path = tp.instruction_sequence.path
          method_registry[path] = tp.instruction_sequence

          # TODO fix this to properly deal with paths
          method_registry[File.basename(path)] = tp.instruction_sequence
        end
        @compiled_trace_point.enable
      end

      def [](path)
        method_registry[path]
      end

      private

      attr_reader :method_registry
    end
  end
end
