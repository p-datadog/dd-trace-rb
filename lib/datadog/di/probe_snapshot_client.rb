module Datadog
  module DI
    # todo: timeout handling
    #
    # @api private
    class ProbeSnapshotClient
      def initialize(agent_settings)
        @client = Net::HTTP.new(agent_settings.hostname, agent_settings.port)
      end

      def dispatch(path, payload)
        headers =
        {
            'content-type' => 'application/json',
        }

        response = client.post(path, JSON.dump(payload), headers)
        unless (200..299).include?(Integer(response.code))
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
