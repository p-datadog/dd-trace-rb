# frozen_string_literal: true

require_relative '../../../core/encoding'
require_relative '../../../core/transport/http/api/map'
require_relative '../../../core/transport/http/api/instance'
require_relative '../../../core/transport/http/api/spec'

module Datadog
  module DI
    module Transport
      module HTTP
        # Namespace for API components
        module API
          # Default API versions
          DIAGNOSTICS = 'diagnostics'
          INPUT = 'input'

          module_function

          def defaults
            Datadog::Core::Transport::HTTP::API::Map[
              DIAGNOSTICS => Spec.new do |s|
                s.diagnostics = Core::Transport::HTTP::API::Endpoint.new(
                  '/debugger/v1/diagnostics',
                  Core::Encoding::JSONEncoder,
                )
              end,
              INPUT => Spec.new do |s|
                s.input = Core::Transport::HTTP::API::Endpoint.new(
                  '/debugger/v1/input',
                  Core::Encoding::JSONEncoder,
                )
              end,
            ]
          end

          class Instance < Core::Transport::HTTP::API::Instance
          end

          class Spec < Core::Transport::HTTP::API::Spec
            attr_accessor :diagnostics
            attr_accessor :input
          end
        end
      end
    end
  end
end
