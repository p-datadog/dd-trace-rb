module Datadog
  module DI
    # @api private
    class ProbeNotifierWorker
      def initialize(agent_settings)
        @status_queue = Queue.new
        @snapshot_queue = Queue.new
        @status_client = ProbeStatusClient.new(agent_settings)
        @snapshot_client = ProbeSnapshotClient.new(agent_settings)
        @wake = ConditionVariable.new
      end

      def add_status(status)
        status_queue << status
        wake.signal
      end

      def add_snapshot
        snapshot_queue << snapshot
        wake.signal
      end

      def start
        return if defined?(@thread)
        @thread = Thread.new do
          loop do
            if maybe_send
              # Run next iteration immediately in case more work is
              # in the queue
            else
              sleep 1
            end
          end
        end
      end

      def stop(timeout = 1)
        wake.signal
        wake.join(timeout)
      end

      private

      attr_reader :status_queue
      attr_reader :snapshot_queue
      attr_reader :status_client
      attr_reader :snapshot_client
      attr_reader :wake

      DIAGNOSTICS_PATH = '/debugger/v1/diagnostics'
      INPUT_PATH = '/debugger/v1/input'

      def maybe_send
        rv = maybe_send_statuses
        rv || maybe_send_snapshots
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
        statuses.any?
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
        snapshots.any?
      end
    end
  end
end
