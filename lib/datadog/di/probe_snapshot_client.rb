module Datadog
  module DI
    # todo: timeout handling
    #
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

        response = client.post(uri.path, JSON.dump(payload), headers)
        unless (200..299).include?(response.code)
          raise Error::AgentCommunicationError, "Probe status submission failed: #{response.code}"
        end
      rescue IOError, SystemCallError => exc
        raise Error::AgentCommunicationError, "Probe status submission failed: #{exc.class}: #{exc}"
      end

      private

      attr_reader :client
    end
  end
end
