module Datadog
  module DI
    # @api private
    class ProbeNotifierWorker
      def initialize(agent_settings)
        @status_queue = Queue.new
        @snapshot_queue = Queue.new
        @status_client = ProbeStatusClient.new(agent_settings)
        @snapshot_client = ProbeSnapshotClient.new(agent_settings)
      end

      def add_status(status)
        status_queue << status
      end

      def add_snapshot
        snapshot_queue << snapshot
      end

      private

      attr_reader :status_queue
      attr_reader :snapshot_queue
      attr_reader :status_client
      attr_reader :snapshot_client

      DIAGNOSTICS_PATH = '/debugger/v1/diagnostics'
      INPUT_PATH = '/debugger/v1/input'

      def maybe_send
        maybe_send_statuses
        maybe_send_snapshots
      end

      def maybe_send_statuses
        statuses = []
        until status_queue.empty?
          statuses << status_queue.shift
        end
        if statuses.any?
          begin
            status_client.dispatch(DIAGNOSTICS_PATH, statuses)
          rescue Error::AgentCommunicationError
            # TODO
            puts "failed to send probe statuses"
          end
        end
      end

      def maybe_send_snapshots
        snapshots = []
        until snapshot_queue.empty?
          snapshots << status_queue.shift
        end
        if snapshots.any?
          begin
            status_client.dispatch(INPUT_PATH, snapshots)
          rescue Error::AgentCommunicationError
            # TODO
            puts "failed to send probe snapshots"
          end
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
