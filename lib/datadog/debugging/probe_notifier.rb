module Datadog
  module Debugging
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

      module_function def notify_executed(probe, tracepoint)
        puts '------------ executing -------------------'
        notify_snapshot(probe)
      end

      module_function def notify_snapshot(probe)
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
              },
            },
            language: 'ruby',
            stack: [],
            captures: nil,
            duration: nil,
          },
          host: nil,
          logger: {
            name: probe.file,
            method: 'fixme',
            thread_name: 'thread name',
            thread_id: 'thread id',
            version: 2,
          },
          'dd.trace_id': 423,
          'dd.span_id': 4234,
          ddsource: 'dd_debugger',
          message: "hello world: #{probe.template}",
          timestamp: timestamp,
        }

        # TODO also send query string parameters
        send_json_payload('/debugger/v1/input', [payload])
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

        send_payload('/debugger/v1/diagnostics', payload)
      end

      module_function def send_payload(path, payload)
        #uri = URI("http://localhost:8126/debugger/v1/diagnostics")
        #http = Net::HTTP.new(uri.host, uri.port)
        http = Datadog::Core::Transport::HTTP::Adapters::Net.new(agent_settings)
        headers =
        {
            'content-type' => 'application/json',
        }

        epayload = Datadog::Core::Vendor::Multipart::Post::UploadIO.new(
          StringIO.new(JSON.dump(payload)), 'application/json', 'event.json')
        env = OpenStruct.new(
          path: path,
          form: {'event' => epayload},
          headers: {},
        )

        puts '-- notifying:'
        pp payload

        response = http.post(env)

        p response
      end

      module_function def send_json_payload(path, payload)
        uri = URI("http://localhost:8126/debugger/v1/input")
        http = Net::HTTP.new(uri.host, uri.port)
        #http = Datadog::Core::Transport::HTTP::Adapters::Net.new(agent_settings)
        headers =
        {
            'content-type' => 'application/json',
        }

        env = OpenStruct.new(
          path: path,
          form: payload,
          headers: headers,
        )

        puts '-- notifying:'
        pp payload

        #response = http.post(env)
        response = http.post(uri.path, JSON.dump(payload), headers)

        p response
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
