module Datadog
  module DI
    # todo: timeout handling
    #
    # @api private
    class ProbeStatusClient
      def initialize(agent_settings)
        @client = Datadog::Core::Transport::HTTP::Adapters::Net.new(agent_settings)
      end

      def dispatch(path, payload)
        headers =
        {
            'content-type' => 'application/json',
        }

        event_payload = Datadog::Core::Vendor::Multipart::Post::UploadIO.new(
          StringIO.new(JSON.dump(payload)), 'application/json', 'event.json')
        payload = {'event' => event_payload}
        env = OpenStruct.new(
          path: path,
          form: payload,
          headers: {},
        )

        response = client.post(env)

        p response
      end

      private

      attr_reader :client
    end
  end
end
