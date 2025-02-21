# frozen_string_literal: true

require_relative 'http/client'

module Datadog
  module DI
    module Transport
      module Diagnostics
        class Transport
          attr_reader :client, :apis, :default_api, :current_api_id

          def initialize(apis, default_api)
            @apis = apis

            @client = HTTP::Client.new(current_api)
          end

          def current_api
            @apis[HTTP::API::DIAGNOSTICS]
          end

          def send_diagnostics(payload)
            request = Core::Transport::Request.new

            @client.send_diagnostics_payload(request)
          end
        end

        module Client
          def send_diagnostics_payload(request)
            send_request(request) do |api, env|
            xx
              api.send_diagnostics(env)
            end
          end
        end
      end

      module Input
        class Transport
          attr_reader :client, :apis, :default_api, :current_api_id

          def initialize(apis, default_api)
            @apis = apis

            @client = HTTP::Client.new(current_api)
          end

          def current_api
            @apis[HTTP::API::INPUT]
          end
        end
      end

      HTTP::Client.include(Diagnostics::Client)
    end
  end
end
