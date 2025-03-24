# frozen_string_literal: true

require_relative 'transport/http'

module Datadog
  module DI
    # Symbol database uploader.
    class SymdbUploader
      def initialize(agent_settings:, logger:)
        @agent_settings = agent_settings
        @logger = logger
        @thread = nil
        @scopes = []
      end

      attr_reader :agent_settings
      attr_reader :logger

      def start
        @thread = Thread.new do
          upload
        end
      end

      def stop
        @thread.kill
        @thread.join
        @thread = nil
      end

      def upload
        # TODO loop and upload new code as it is loaded.
        # Can use code tracker to be notified about newly loaded code.
        $LOADED_FEATURES.each do |path|
          add_path(path)
        end
        flush
      end

      private

      def add_path(path)
        @scopes << {
          scope_type: 'FILE', source_file: path, name: path,
          symbols: [name: path, symbol_type: 'FILE', type: 'file'],
        }
      end

      def flush
        transport.send_symdb(@scopes)
      end

      def transport
        @transport ||= DI::Transport::HTTP.symdb(agent_settings: agent_settings)
      end
    end
  end
end
