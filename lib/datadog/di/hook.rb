require 'concurrent-ruby'
require 'benchmark'
require 'byebug'

module Datadog
  module DI
    module Hook
      module_function def clear_hooks
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

      module_function def hook_method(cls_name, meth_name)
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

      module_function def hook_line(file, line_no, &block)
        # TODO is file a basename, path suffix or full path?
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

          tp.enable
        end
      end

      private

      INSTRUMENTED_METHODS = Concurrent::Map.new
      INSTRUMENTED_LINES = Concurrent::Map.new
      TRACEPOINTS = Concurrent::Map.new
      NEXT_MUTEX = Mutex.new
      TRACEPOINT_MUTEX = Mutex.new

      module_function def next_id
        NEXT_MUTEX.synchronize do
          @next_id ||= 0
          @next_id += 1
        end
      end

      module_function def symbolize_class_name(cls_name)
        Object.const_get(cls_name)
      end

      module_function def on_line_tracepoint(tp, **opts)
        cb = INSTRUMENTED_LINES[tp.lineno]&.[](File.basename(tp.path))
        puts "*** line tracepoint: #{cb}" if cb
        #p tp.object_id
        #p tp if cb
        cb&.call(tp, **opts)
      end
    end
  end
end
