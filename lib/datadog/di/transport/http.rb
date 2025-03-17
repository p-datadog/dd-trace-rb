# frozen_string_literal: true

require_relative '../../core/environment/container'
require_relative '../../core/environment/ext'
require_relative '../../core/transport/ext'
require_relative '../../core/transport/http'
require_relative 'http/api'
require_relative 'diagnostics'
require_relative 'input'
require_relative 'symdb'

module Datadog
  module DI
    module Transport
      # Namespace for HTTP transport components
      module HTTP
        module_function

        # Builds a new Transport::HTTP::Client with default settings
        # Pass a block to override any settings.
        def diagnostics(
          agent_settings:,
          logger:,
          api_version: nil,
          headers: nil
        )
          Core::Transport::HTTP.build(api_instance_class: Diagnostics::API::Instance,
            logger: logger,
            agent_settings: agent_settings, api_version: api_version, headers: headers) do |transport|
            apis = API.defaults

            transport.api API::DIAGNOSTICS, apis[API::DIAGNOSTICS]

            # Call block to apply any customization, if provided
            yield(transport) if block_given?
          end.to_transport(DI::Transport::Diagnostics::Transport)
        end

        # Builds a new Transport::HTTP::Client with default settings
        # Pass a block to override any settings.
        def input(
          agent_settings:,
          logger:,
          api_version: nil,
          headers: nil
        )
          Core::Transport::HTTP.build(api_instance_class: Input::API::Instance,
            logger: logger,
            agent_settings: agent_settings, api_version: api_version, headers: headers) do |transport|
            apis = API.defaults

            transport.api API::INPUT, apis[API::INPUT]

            # Call block to apply any customization, if provided
            yield(transport) if block_given?
          end.to_transport(DI::Transport::Input::Transport)
        end

        # Builds a new Transport::HTTP::Client with default settings
        # Pass a block to override any settings.
        def symdb(
          agent_settings:,
          logger:,
          api_version: nil,
          headers: nil
        )
          Core::Transport::HTTP.build(api_instance_class: Symdb::API::Instance,
            logger: logger,
            agent_settings: agent_settings, api_version: api_version, headers: headers) do |transport|
            apis = API.defaults

            transport.api API::SYMDB, apis[API::SYMDB]

            # Call block to apply any customization, if provided
            yield(transport) if block_given?
          end.to_transport(DI::Transport::Symdb::Transport)
        end
      end
    end
  end
end
