# frozen_string_literal: true

require_relative '../../../core/encoding'
require_relative '../../../core/transport/http/api/map'

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
                s.traces = Traces::API::Endpoint.new(
                  '/debugger/v1/diagnostics',
                  Core::Encoding::JsonEncoder,
                )
              end,
              INPUT => Spec.new do |s|
                s.traces = Traces::API::Endpoint.new(
                  '/debugger/v1/input',
                  Core::Encoding::JsonEncoder,
                )
              end,
            ]
          end
        end
      end
    end
  end
end
