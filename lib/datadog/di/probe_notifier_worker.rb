module Datadog
  module DI
    # @api private
    class ProbeNotifierWorker
      def initialize
        @status_queue = Queue.new
        @snapshot_queue = Queue.new
      end

      attr_reader :status_queue
      attr_reader :snapshot_queue

      def add_status(status)
        status_queue << status
      end

      def add_snapshot
        snapshot_queue << snapshot
      end

      private

      def maybe_send
        statuses = []
        until status_queue.empty?
          statuses << status_queue.shift
        end
        if statuses.any?
        end
      end

      def run
        Thread.new do
          loop do
            maybe_send
            sleep 1
          end
        end
      end
    end
  end
end
