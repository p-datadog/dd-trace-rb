# frozen_string_literal: true

module Datadog
  module DI
    # Tracks loaded Ruby code by source file and maintains a map from
    # source file to the loaded code (instruction sequences).
    #
    # The loaded code is used to target line trace points when installing
    # line probes which dramatically improves efficiency of line trace points.
    #
    # Note that, since most files will only be loaded one time (via the
    # "require" mechanism), the code tracker needs to be global and not be
    # recreated when the DI component is created.
    class CodeTracker
      def initialize
        @registry = Concurrent::Map.new
      end

      def start
        # If this code tracker is already running, we can do nothing or
        # restart it (by disabling the trace point and recreating it).
        # It is likely that some applications will attempt to activate
        # DI more than once where the intention is to just activate DI;
        # do not break such applications by clearing out the registry.
        # For now, until there is a use case for recreating the trace point,
        # do nothing if the code tracker has already started.
        return if @compiled_trace_point

        @compiled_trace_point = TracePoint.trace(:script_compiled) do |tp|
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
          registry[path] = tp.instruction_sequence

          # TODO fix this to properly deal with paths
          registry[File.basename(path)] = tp.instruction_sequence

          DI.component&.hook_manager&.install_pending_line_hooks(path)
        end
      end

      # Returns whether this code tracker has been activated and is
      # tracking.
      def active?
        # TODO does this need to be locked?
        !!@compiled_trace_point
      end

      # Returns the RubVM::InstructionSequence (i.e. the compiled code)
      # for the provided path.
      def [](path)
        registry[path]
      end

      def stop
        # Permit multiple stop calls.
        @compiled_trace_point&.disable
        # Clear the instance variable so that the trace point may be
        # reinstated in the future.
        @compiled_trace_point = nil
        registry.clear
      end

      private

      # Mapping from paths of loaded files to RubyVM::InstructionSequence
      # objects representing compiled code of those files.
      attr_reader :registry
    end
  end
end
