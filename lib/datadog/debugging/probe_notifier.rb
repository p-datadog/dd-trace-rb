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

      module_function def notify_executed(probe, tracepoint)
        puts 'executing'
      end

      module_function def notify(probe, message:, status:)
        payload = {
          service: Datadog.configuration.service,
          timestamp: (Time.now.to_f * 1000).to_i,
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

        uri = URI("http://localhost:8126/debugger/v1/diagnostics")
        #http = Net::HTTP.new(uri.host, uri.port)
        http = Datadog::Core::Transport::HTTP::Adapters::Net.new(agent_settings)
        headers =
        {
            'content-type' => 'application/json',
        }

        epayload = Datadog::Core::Vendor::Multipart::Post::UploadIO.new(
          StringIO.new(JSON.dump(payload)), 'application/json', 'event.json')
        env = OpenStruct.new(
          path: '/debugger/v1/diagnostics',
          form: {'event' => epayload},
          headers: {},
        )

        puts '-- notifying:'
        pp payload

        response = http.post(env)

        p response
      end

      module_function def agent_settings
        settings = Datadog.configuration
        Core::Configuration::AgentSettingsResolver.call(settings, logger: @logger)
      end
    end
  end
end
