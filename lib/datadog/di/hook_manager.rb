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
    # Line hooking is currently done with a naive line trace point which
    # imposes no requirements on the code being instrumented, but carries
    # a serious performance penalty for the entire running application.
    #
    # An alternative line hooking implementation is to use targeted line
    # trace points. These require all code to be instrumented to have been
    # loaded after a require trace point is installed to map the loaded
    # code to its files, and the trace point then targets the particular
    # code object where the instrumented code is defined.
    # The targeted trace points rewrites VM instructions to trigger the
    # trace points on the desired line and otherwise has no performance
    # impact on the application.
    #
    # @api private
    class HookManager
      def initialize(settings)
        @settings = settings

        @pending_methods = Concurrent::Map.new
        @pending_lines = Concurrent::Map.new
        @instrumented_methods = Concurrent::Map.new
        @instrumented_lines = Concurrent::Map.new
        @trace_points = Concurrent::Map.new
        @next_mutex = Mutex.new
        @trace_point_mutex = Mutex.new

        @definition_trace_point = TracePoint.trace(:end) do |tp|
          # TODO search more efficiently than linearly
          pending_methods.each do |pm, block|
            cls_name, method_name = pm
            # TODO move this stringification elsewhere
            if cls_name.to_s == tp.self.name
              # TODO is it OK to hook from trace point handler?
              # TODO the class is now defined, but can hooking still fail?
              hook_method(cls_name, method_name, &block)
              pending_methods.delete(pm)
            end
          end
        end
      end

      attr_reader :settings

      # TODO test that close is called during component teardown and
      # the trace point is cleared
      def close
        definition_trace_point.disable
      end

      def clear_hooks
        trace_point_mutex.synchronize do
          instrumented_methods.clear
          instrumented_lines.clear
          trace_points.each do |line, submap|
            submap.each do |file, trace_point|
              trace_point.disable
            end
          end
          trace_points.clear
        end
      end

      def hook_method(cls_name, meth_name)
        cls = symbolize_class_name(cls_name)
        id = next_id

        cls.class_eval do
          saved = instance_method(meth_name)

          remove_method(meth_name)
          define_method(meth_name) do |*args, **kwargs|
            if DI.component.hook_manager.instrumented_methods[[cls_name, meth_name]] == id
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

        instrumented_methods[[cls_name, meth_name]] = id
      end

      def hook_method_when_defined(cls_name, meth_name, &block)
        begin
          hook_method(cls_name, meth_name, &block)
          true
        rescue Error::DITargetNotDefined
          pending_methods[[cls_name, meth_name]] = block
          false
        end
      end

      # Instruments a particluar line in a source file.
      # Note that this method only works for physical files,
      # not for eval'd code, unless the eval'd code is associated with
      # a filenam and client invokes this method with the correct
      # file name for the eval'd code.
      def hook_line(file, line_no, &block)
        # TODO is file a basename, path suffix or full path?
        # Maybe support all?
        file = File.basename(file)

        iseq = nil
        # TODO global reference
        if DI.code_tracking_active?
          iseq = DI.code_tracker[file]
          unless iseq
            if settings.internal_dynamic_instrumentation.untargeted_trace_points
              # Continue withoout targeting the trace point.
              # This is going to cause a serious performance penalty for
              # the entire file containing the line to be instrumented.
            else
              # Do not use untargeted trace points unless they have been
              # explicitly requested by the user, since they cause a
              # serious performance penalty.
              #
              # If the requested file is not in code tracker's registry,
              # or the code tracker does not exist at all,
              # do not attempt to instrumnet now.
              # The caller should add the line to the list of pending lines
              # to instrument and install the hook when the file in
              # question is loaded (and hopefully, by then code tracking
              # is active, otherwise the line will never be instrumented.)
              raise Error::DITargetNotDefined, "File #{file} not in code tracker registry"
            end
          end
        elsif !settings.internal_dynamic_instrumentation.untargeted_trace_points
          # Same as previous comment, if untargeted trace points are not
          # explicitly defined, and we do not have code tracking, do not
          # instrument the method.
          raise Error::DITargetNotDefined, "File #{file} not in code tracker registry"
        end

        instrumented_lines[line_no] ||= {}
        instrumented_lines[line_no][file] = block

        # TODO if trace point is not targeted, we only need one
        # trace point per file, not one per line.
        # Trace point per line should still function but the performance
        # penalty will be taken for each trace point defined in the file.

        trace_point_mutex.synchronize do
          # Delete previous trace point, if any.
          # We could have reused the previous trace point but there are
          # comments elsewhere in the datadog codebase about trace_points
          # needing to be reinstalled on occasion, therefore be safe and
          # create a new trace point here.
          tp = trace_points[line_no]&.[](file)
          tp&.disable

          tp = TracePoint.new(:line) do |tp|
            on_line_trace_point(tp, callers: caller, &block)
          end

          # Put the trace point into our tracking map first to prevent
          # possible leakage if enabling it fails for any reason.
          trace_points[line_no] ||= {}
          trace_points[line_no][file] = tp

          iseq = DI.code_tracker&.[](file)

          # TODO internal check - remove or use a proper exception
          if !iseq && !settings.internal_dynamic_instrumentation.untargeted_trace_points
            raise "Trying to use an untargeted trace point when user did not permit it"
          end

          tp.enable(target: iseq)
        end
      end

      def hook_line_when_defined(file, line_no, &block)
        begin
          hook_line(file, line_no, &block)
          true
        rescue Error::DITargetNotDefined
          pending_lines[[file, line_no]] = block
          false
        end
      end

      def install_pending_line_hooks(file)
        pending_lines.each do |spec, block|
          spec_file, spec_line = spec
          # TODO handle paths properly
          if File.basename(file) == spec_file
            begin
              hook_line(spec_file, spec_line, &block)
            rescue Error::DITargetNotDefined
              # Maybe line is out of range?
              # TODO reconsider what to do here
              next
            end

            # TODO this is not thread-safe, all operations on
            # pending_lines must be under a single lock
            pending_lines.delete(spec)
          end
        end
      end

      attr_reader :pending_methods
      attr_reader :pending_lines
      attr_reader :instrumented_methods
      attr_reader :instrumented_lines

      private

      attr_reader :trace_points
      attr_reader :next_mutex
      attr_reader :trace_point_mutex

      # Class/module definition trace point (:end type).
      # Used to install hooks when the target classes/modules aren't yet
      # defined when the hook request is received.
      attr_reader :definition_trace_point

      def next_id
        next_mutex.synchronize do
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

      def on_line_trace_point(tp, **opts)
        cb = instrumented_lines[tp.lineno]&.[](File.basename(tp.path))
        cb&.call(tp, **opts)
      end
    end
  end
end
