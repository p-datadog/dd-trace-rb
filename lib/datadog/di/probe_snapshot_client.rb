module Datadog
  module DI
    # @api private
    class ProbeSnapshotClient
      def initialize(agent_settings)
        #uri = URI("http://localhost:8126/debugger/v1/input")
        @client = Net::HTTP.new(agent_settings.hostname, uri.port)
        #http = Datadog::Core::Transport::HTTP::Adapters::Net.new(agent_settings)
      end

      def dispatch(path, payload)
        headers =
        {
            'content-type' => 'application/json',
        }

        env = OpenStruct.new(
          path: path,
          form: payload,
          headers: headers,
        )

        response = client.post(uri.path, JSON.dump(payload), headers)

        p response
      end

      private

      attr_reader :client
    end
  end
end
