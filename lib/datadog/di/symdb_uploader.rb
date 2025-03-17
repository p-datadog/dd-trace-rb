# frozen_string_literal: true

module Datadog
  module DI
    # Symbol database uploader.
    class SymdbUploader
      def initialize(logger:)
        @logger = logger
        @thread = nil
      end

      attr_reader :logger

      def start
        @thread = Thread.new do
        end
      end

      def stop
        @thread.kill
        @thread.join
        @thread = nil
      end
    end
  end
end
