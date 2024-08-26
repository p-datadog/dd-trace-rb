module Datadog
  module DI
    # @api private
    module ProbeNotifier

      module_function def notify_received(probe)
        notify(probe,
          message: "Probe #{probe.id} has been received correctly",
          status: 'RECEIVED',
        )
      end

      module_function def notify_installed(probe)
        notify(probe,
          message: "Probe #{probe.id} has been instrumented correctly",
          status: 'INSTALLED',
        )
      end

      module_function def notify_emitting(probe)
        notify(probe,
          message: "Probe #{probe.id} is emitting",
          status: 'EMITTING',
        )
      end

      module_function def notify_executed(probe,
        tracepoint: nil, rv: nil, duration: nil, callers: nil,
        args: nil, kwargs: nil
      )
        snapshot = if probe.line? && probe.capture_snapshot?
          if tracepoint.nil?
            raise "Cannot create snapshot because there is no trace point"
          end
          get_local_variables(tracepoint)
        end
        if callers
          callers = callers[0..9]
        end
        notify_snapshot(probe, rv: rv, snapshot: snapshot,
          duration: duration, callers: callers, args: args, kwargs: kwargs)
      end

      module_function def notify_snapshot(probe, rv: nil, snapshot: nil,
        duration: nil, callers: nil, args: nil, kwargs: nil
      )
        component = DI.component
        # Component can be nil in unit tests.
        return unless component

        serializer = component.serializer

        # TODO also verify that non-capturing probe does not pass
        # snapshot or vars/args into this method
        captures = if probe.capture_snapshot?
          if probe.method?
            {
              entry: {
                arguments: (args || kwargs) && serializer.serialize_args(args, kwargs),
                throwable: nil,
              },
              return: {
                arguments: {
                  '@return': serializer.serialize_value(nil, rv),
                },
                throwable: nil,
              },
            }
          elsif probe.line?
            {
              lines: snapshot && {
                probe.line_no => {locals: serializer.serialize_vars(snapshot)},
              },
            }
          end
        end

        location = if probe.line?
          actual_file = if probe.file
            # Normally callers should always be filled for a line probe
            # but in the test suite we don't always provide all arguments.
            callers&.detect do |caller|
              File.basename(caller.sub(/:.*/, '')) == File.basename(probe.file)
            end&.sub(/:.*/, '') || probe.file
          end
          {
            file: actual_file,
            lines: probe.line_nos,
          }
        elsif probe.method?
          {
            method: probe.method_name,
            type: probe.type_name,
          }
        end

        stack = if callers
          format_callers(callers)
        end

        timestamp = timestamp_now
        payload = {
          service: Datadog.configuration.service,
          'debugger.snapshot': {
            id: SecureRandom.uuid,
            timestamp: timestamp,
            evaluationErrors: [],
            probe: {
              id: probe.id,
              version: 0,
              location: location,
            },
            language: 'ruby',
            #language: 'python',
            # TODO add test coverage for callers being nil
            stack: stack,
            captures: captures,
          },
          # In python tracer duration is under debugger.snapshot,
          # but UI appears to expect it here at top level.
          duration: duration ? (duration * 10**9).to_i : nil,
          host: nil,
          logger: {
            name: probe.file,
            method: probe.method_name || 'no_method',
            thread_name: Thread.current.name,
            thread_id: Thread.current.native_thread_id,
            version: 2,
          },
          'dd.trace_id': 136035165280417366521542318182735500431,
          'dd.span_id': 17576285113343575026,
          ddsource: 'dd_debugger',
          message: probe.template && evaluate_template(probe.template,
            duration: duration ? duration * 1000 : nil),
          timestamp: timestamp,
        }
        pp payload

        component.probe_notifier_worker.add_snapshot(payload)
      end

      module_function def notify(probe, message:, status:)
        component = DI.component
        # Component can be nil in unit tests.
        return unless component

        payload = {
          service: Datadog.configuration.service,
          timestamp: timestamp_now,
          message: message,
          ddsource: 'dd_debugger',
          debugger: {
            diagnostics: {
              probeId: probe.id,
              probeVersion: 0,
              runtimeId: Core::Environment::Identity.id,
              parentId: nil,
              status: status,
            },
          },
        }

        component.probe_notifier_worker.add_status(payload)
      end

      module_function def format_callers(callers)
        callers.map do |caller|
          if caller =~ /\A(.+):(\d+):in `([^']+)'\z/
            {
              fileName: $1, function: $3, lineNumber: Integer($2),
            }
          else
            {
              fileName: 'unknown', function: 'unknown', lineNumber: 0,
            }
          end
        end
      end

      module_function def value_type(value)
        case value
        when Integer
          'int'
        when String
          'string'
        else
          'something else'
        end
      end

      module_function def evaluate_template(template, **vars)
        message = template.dup
        vars.each do |key, value|
          message.gsub!("{@#{key}}", value.to_s)
        end
        message
      end

      module_function def timestamp_now
        (Time.now.to_f * 1000).to_i
      end

      module_function def get_local_variables(trace_point)
        trace_point.binding.local_variables.inject({}) do |map, name|
          value = trace_point.binding.local_variable_get(name)
          map[name] = {
            value: value,
            type: value.class.name,
          }
          map
        end
      end

    end
  end
end
