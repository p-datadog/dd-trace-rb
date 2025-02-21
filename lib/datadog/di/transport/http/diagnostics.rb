# frozen_string_literal: true

require_relative 'client'

module Datadog
  module DI
    module Transport
      module HTTP
        module Diagnostics
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

            # Endpoint for negotiation
            class Endpoint < Datadog::Core::Transport::HTTP::API::Endpoint
              attr_reader :encoder

              def initialize(path, encoder)
                super(:post, path)
                @encoder = encoder
              end

              def call(env, &block)
                # Add trace count header
                # env.headers[HEADER_TRACE_COUNT] = env.request.parcel.trace_count.to_s

                # Encode body & type
                # require'byebug';byebug
                # env.headers[HEADER_CONTENT_TYPE] = encoder.content_type
                # env.body = env.request.parcel.data
                event_payload = Core::Vendor::Multipart::Post::UploadIO.new(
                  StringIO.new(JSON.dump(env.request.parcel.data)), 'application/json', 'event.json'
                )
                env.form = {'event' => event_payload}

                super(env, &block)
              end
            end
          end
        end

        HTTP::Client.include(Diagnostics::Client)
      end
    end
  end
end
