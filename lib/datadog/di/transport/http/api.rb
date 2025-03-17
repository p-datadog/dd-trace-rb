# frozen_string_literal: true

require_relative '../../../core/encoding'
require_relative '../../../core/transport/http/api/map'
require_relative '../../../core/transport/http/api/instance'
require_relative '../../../core/transport/http/api/spec'
require_relative 'diagnostics'
require_relative 'input'
require_relative 'symdb'

module Datadog
  module DI
    module Transport
      module HTTP
        # Namespace for API components
        module API
          # Default API versions
          DIAGNOSTICS = 'diagnostics'
          INPUT = 'input'
          SYMDB = 'symdb'

          module_function

          def defaults
            Datadog::Core::Transport::HTTP::API::Map[
              DIAGNOSTICS => Diagnostics::API::Spec.new do |s|
                s.diagnostics = Diagnostics::API::Endpoint.new(
                  '/debugger/v1/diagnostics',
                  Core::Encoding::JSONEncoder,
                )
              end,
              INPUT => Input::API::Spec.new do |s|
                s.input = Input::API::Endpoint.new(
                  '/debugger/v1/input',
                  Core::Encoding::JSONEncoder,
                )
              end,
              SYMDB => Symdb::API::Spec.new do |s|
                s.symdb = Symdb::API::Endpoint.new(
                  '/symdb/v1/input',
                  Core::Encoding::JSONEncoder,
                )
              end,
            ]
          end
        end
      end
    end
  end
end
