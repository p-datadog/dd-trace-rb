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
              DIAGNOSTICS => Spec.new do |s|
                s.diagnostics = Diagnostics::API::Endpoint.new(
                  '/debugger/v1/diagnostics',
                  Core::Encoding::JSONEncoder,
                )
              end,
              INPUT => Spec.new do |s|
                s.input = Input::API::Endpoint.new(
                  '/debugger/v1/input',
                  Core::Encoding::JSONEncoder,
                )
              end,
              SYMDB => Spec.new do |s|
                s.symdb = Symdb::API::Endpoint.new(
                  '/symdb/v1/input',
                  Core::Encoding::JSONEncoder,
                )
              end,
            ]
          end

          class Instance < Core::Transport::HTTP::API::Instance
            include Diagnostics::API::Instance
            include Input::API::Instance
            include Symdb::API::Instance
          end

          class Spec < Core::Transport::HTTP::API::Spec
            include Diagnostics::API::Spec
            include Input::API::Spec
            include Symdb::API::Spec
          end
        end
      end
    end
  end
end
