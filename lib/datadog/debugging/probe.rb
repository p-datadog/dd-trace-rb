module Datadog
  module Debugging
    class Probe

      def self.from_remote_config(config)
        new(
          id: config.fetch('id'),
          type: config.fetch('type'),
        )
      end

      def initialize(id:, type:)
        @id = id
        @type = type
      end

      attr_reader :id
      attr_reader :type

      def notify_received
        payload = {
          service: 'service name',
          timestamp: (Time.now.to_f * 1000).to_i,
          message: "Probe #{id} has been received correctly",
          ddsource: 'dd_debugger',
          debugger: {
            diagnostics: {
              probeId: id,
              probeVersion: 0,
              runtimeId: 'runtime id',
              parentId: nil,
              status: 'RECEIVED',
            },
          },
        }

        uri = URI("http://localhost:8126/debugger/v1/diagnostics")
        http = Net::HTTP.new(uri.host, uri.port)
        #http = Datadog::Core::Transport::HTTP::Adapters::Net::HTTP.new(uri.host, uri.port)
        headers =
        {
            'content-type' => 'application/json',
        }

        body = JSON.dump(payload)
        response = http.post(uri.path, body)

        p response
      end
    end
  end
end

