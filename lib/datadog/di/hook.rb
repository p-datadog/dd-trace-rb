require 'concurrent-ruby'
require 'byebug'

module Datadog
  module DI
    module Hook
      module_function def clear_hooks
        INSTRUMENTED_METHODS.clear
        INSTRUMENTED_LINES.clear

        TRACEPOINT_MUTEX.synchronize do
          @tracepoint&.disable
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
              yield rv: rv, duration: duration
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
        p '--'
        pp INSTRUMENTED_LINES.each.to_a

        TRACEPOINT_MUTEX.synchronize do
          $tracepoint ||= TracePoint.new(:line) do |tp|
          #puts '******* tracepoint invoked ************'
            on_line_tracepoint(tp, &block)
          end

          $tracepoint.enable
        end
      end

      private

      INSTRUMENTED_METHODS = Concurrent::Map.new
      INSTRUMENTED_LINES = Concurrent::Map.new
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

      module_function def on_line_tracepoint(tp)
        cb = INSTRUMENTED_LINES[tp.lineno]&.[](File.basename(tp.path))
        puts "*** line tracepoint: #{cb}" if cb
        #p tp.object_id
        #p tp if cb
        cb&.call(tp)
      end
    end
  end
end
