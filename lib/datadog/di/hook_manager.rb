require 'concurrent-ruby'
require 'benchmark'

module Datadog
  module DI
    # Arranges to invoke a callback when a particular Ruby method or
    # line of code is executed.
    #
    # The method hooking is currently accomplished via method aliasing.
    # Unlike the traditional alias_method_chain pattern, the original
    # method is stored in a local variable and is thus not leaking out.
    # This should also prevent possible issues with infinite loops
    # when the original or the aliased method is called incorrerctly
    # due to conflicting aliasing happening.
    #
    # Note that only explicitly defined methods can be hooked, e.g. if a
    # class has a +method_missing+ method that provides further virtual
    # methods, the hooking must be done on the +method_missing+ method
    # and not on one of the virtual methods provided by it.
    #
    # TODO with module prepending virtual methods may be instrumentable
    # anyway?
    #
    # Line hooking is currently done with a naive line tracepoint which
    # imposes no requirements on the code being instrumented, but carries
    # a serious performance penalty for the entire running application.
    #
    # An alternative line hooking implementation is to use targeted line
    # tracepoints. These require all code to be instrumented to have been
    # loaded after a require tracepoint is installed to map the loaded
    # code to its files, and the tracepoint then targets the particular
    # code object where the instrumented code is defined.
    # The targeted tracepoints rewrites VM instructions to trigger the
    # tracepoints on the desired line and otherwise has no performance
    # impact on the application.
    #
    # @api private
    class HookManager
      def initialize
        @definition_trace_point = TracePoint.new(:end) do |tp|
        end
        definition_trace_point.enable
      end

      # TODO test that close is called during component teardown and
      # the trace point is cleared
      def close
        definition_trace_point.disable
      end

      def clear_hooks
        TRACEPOINT_MUTEX.synchronize do
          INSTRUMENTED_METHODS.clear
          INSTRUMENTED_LINES.clear
          TRACEPOINTS.each do |line, submap|
            submap.each do |file, tracepoint|
              tracepoint.disable
            end
          end
          TRACEPOINTS.clear
        end
      end

      def hook_method(cls_name, meth_name)
        cls = symbolize_class_name(cls_name)
        id = next_id

        cls.class_eval do
          saved = instance_method(meth_name)

          remove_method(meth_name)
          define_method(meth_name) do |*args, **kwargs|
            if INSTRUMENTED_METHODS[[cls_name, meth_name]] == id
              rv = nil
              duration = Benchmark.realtime do
                rv = saved.bind(self).call(*args, **kwargs)
              end
              yield rv: rv, duration: duration, callers: caller
              rv
            else
              saved.bind(self).call(*args, **kwargs)
            end
          end
        end

        INSTRUMENTED_METHODS[[cls_name, meth_name]] = id
      end

      def hook_line(file, line_no, &block)
        # TODO is file a basename, path suffix or full path?
        # Maybe support all?
        file = File.basename(file)

        INSTRUMENTED_LINES[line_no] ||= {}
        INSTRUMENTED_LINES[line_no][file] = block

        TRACEPOINT_MUTEX.synchronize do
          # Delete previous tracepoint, if any.
          # We could have reused the previous tracepoint but there are
          # comments elsewhere in the datadog codebase about tracepoints
          # needing to be reinstalled on occasion, therefore be safe and
          # create a new tracepoint here.
          tp = TRACEPOINTS[line_no]&.[](file)
          tp&.disable

          tp = TracePoint.new(:line) do |tp|
            on_line_tracepoint(tp, callers: caller, &block)
          end

          # Put the tracepoint into our tracking map first to prevent
          # possible leakage if enabling it fails for any reason.
          TRACEPOINTS[line_no] ||= {}
          TRACEPOINTS[line_no][file] = tp

          iseq = DI.code_tracker&.[](file)

          tp.enable(target: iseq)
        end
      end

      private

      # Class/module definition trace point  (:end type).
      # Used to install hooks when the target classes/modules aren't yet
      # defined when the hook request is received.
      attr_reader :definition_trace_point

      INSTRUMENTED_METHODS = Concurrent::Map.new
      INSTRUMENTED_LINES = Concurrent::Map.new
      TRACEPOINTS = Concurrent::Map.new
      NEXT_MUTEX = Mutex.new
      TRACEPOINT_MUTEX = Mutex.new

      def next_id
        NEXT_MUTEX.synchronize do
          @next_id ||= 0
          @next_id += 1
        end
      end

      # TODO test that this resolves qualified names e.g. A::B
      def symbolize_class_name(cls_name)
        Object.const_get(cls_name)
      rescue NameError => exc
        raise Error::DITargetNotDefined, "Class not defined: #{cls_name}: #{exc.class}: #{exc}"
      end

      def on_line_tracepoint(tp, **opts)
        cb = INSTRUMENTED_LINES[tp.lineno]&.[](File.basename(tp.path))
        cb&.call(tp, **opts)
      end
    end
  end
end
