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
              api.send_diagnostics(env)
            end
          end
        end

        module API
          module Instance
            def send_diagnostics(env)
              raise TracesNotSupportedError, spec unless spec.is_a?(Diagnostics::API::Spec)

              spec.send_diagnostics(env) do |request_env|
                call(request_env)
              end
            end
          end
          
          module Spec
            attr_accessor :diagnostics

            def send_diagnostics(env, &block)
              raise NoTraceEndpointDefinedError, self if diagnostics.nil?

              diagnostics.call(env, &block)
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

      HTTP::Client.include(Diagnostics::Client)
    end
  end
end
