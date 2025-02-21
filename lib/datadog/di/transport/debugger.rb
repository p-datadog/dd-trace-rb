# frozen_string_literal: true

require_relative 'http/client'

module Datadog
  module DI
    module Transport
      module Debugger
        # Debugger transport
        class Transport
          attr_reader :client, :apis, :default_api, :current_api_id

          def initialize(apis, default_api)
            @apis = apis

            @client = HTTP::Client.new(current_api)
          end

          def current_api
            @apis[HTTP::API::ROOT]
          end
        end
      end
    end
  end
end
