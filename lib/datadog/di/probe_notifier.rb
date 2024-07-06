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
        tracepoint: nil, rv: nil, duration: nil, callers: nil
      )
        notify_snapshot(probe, rv: rv, duration: duration, callers: callers)
      end

      module_function def notify_snapshot(probe, rv: nil, duration: nil, callers: nil)
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
              location: {
                file: probe.file,
                lines: probe.line_nos,
                method: probe.method_name,
                type: probe.type_name,
              },
            },
            language: 'ruby',
            #language: 'python',
            stack: format_callers(callers),
            captures: {
              entry: {
                arguments: {},
                locals: {},
                throwable: nil,
              },
              return: {
                arguments: {},
                locals: {
                  '@return': {
                    value: rv.to_s,
                    type: rv.class.name,
                  },
                },
                throwable: nil,
              },
            },
          },
          # In python tracer duration is under debugger.snapshot,
          # but UI appears to expect it here at top level.
          duration: duration ? (duration * 10**9).to_i : nil,
          host: nil,
          logger: {
            name: probe.file,
            method: probe.method_name,
            thread_name: Thread.current.name,
            thread_id: Thread.current.native_thread_id,
            version: 2,
          },
          'dd.trace_id': 423.to_s,
          'dd.span_id': 4234.to_s,
          ddsource: 'dd_debugger',
          message: evaluate_template(probe.template,
            duration: duration ? duration * 1000 : nil),
          timestamp: timestamp,
        }

        DI.component.probe_notifier_worker.add_snapshot(payload)
      end

      module_function def notify(probe, message:, status:)
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

        DI.component.probe_notifier_worker.add_status(payload)
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

      module_function def send_payload(path, payload)
        client = ProbeStatusClient.new(agent_settings)
        client.dispatch(path, payload)
      end

      module_function def send_json_payload(path, payload)
        client = ProbeSnapshotClient.new(agent_settings)
        client.dispatch(path, payload)
      end

      module_function def timestamp_now
        (Time.now.to_f * 1000).to_i
      end

      module_function def agent_settings
        settings = Datadog.configuration
        Core::Configuration::AgentSettingsResolver.call(settings, logger: @logger)
      end
    end
  end
end
