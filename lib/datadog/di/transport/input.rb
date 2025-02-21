# frozen_string_literal: true

require_relative 'http/client'

module Datadog
  module DI
    module Transport
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

        module Client
          def send_input_payload(request)
            send_request(request) do |api, env|
              api.send_input(env)
            end
          end
        end

        module API
          module Instance
            def send_input(env)
              raise TracesNotSupportedError, spec unless spec.is_a?(Input::API::Spec)

              spec.send_input(env) do |request_env|
                call(request_env)
              end
            end
          end
          
          module Spec
            attr_accessor :input

            def send_input(env, &block)
              raise NoTraceEndpointDefinedError, self if input.nil?

              input.call(env, &block)
            end

            # Raised when traces sent but no traces endpoint is defined
            class NoTraceEndpointDefinedError < StandardError
              attr_reader :spec

              def initialize(spec)
                super

                @spec = spec
              end

              def message
                'No trace endpoint is defined for API specification!'
              end
            end
          end
        end
      end

      HTTP::Client.include(Input::Client)
    end
  end
end
