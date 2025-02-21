# frozen_string_literal: true

require_relative '../../core/transport/parcel'
require_relative 'http/client'

module Datadog
  module DI
    module Transport
      module Input

        class EncodedParcel
          include Datadog::Core::Transport::Parcel
        end

        class Request < Datadog::Core::Transport::Request
        end

        class Transport
          attr_reader :client, :apis, :default_api, :current_api_id

          def initialize(apis, default_api)
            @apis = apis

            @client = HTTP::Client.new(current_api)
          end

          def current_api
            @apis[HTTP::API::INPUT]
          end

          def send_input(payload)
            json = JSON.dump(payload)
            parcel = EncodedParcel.new(json)
            request = Request.new(parcel)

            @client.send_input_payload(request)
          end
        end
      end
    end
  end
end
