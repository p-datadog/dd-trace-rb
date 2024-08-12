module Datadog
  module DI
    # @api private
    class ProbeNotifierWorker
      def initialize(settings, agent_settings)
        @settings = settings
        @status_queue = Queue.new
        @snapshot_queue = Queue.new
        @status_client = ProbeStatusClient.new(agent_settings)
        @snapshot_client = ProbeSnapshotClient.new(agent_settings)
        @wake = ConditionVariable.new
      end

      attr_reader :settings

      def add_status(status)
        status_queue << status
        wake.signal
      end

      def add_snapshot(snapshot)
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
          statuses << status_queue.shift(true)
        end
        if statuses.any?
          begin
            status_client.dispatch(DIAGNOSTICS_PATH, statuses)
          rescue Error::AgentCommunicationError => exc
            raise if settings.internal_dynamic_instrumentation.propagate_all_exceptions
            # TODO
            puts "failed to send probe statuses: #{exc.class}: #{exc}"
          end
        end
        statuses.any?
      rescue ThreadError
        # Normally the queue should only be consumed in this method,
        # however if anyone consumes it elsewhere we don't want to block
        # while consuming it here. Rescue ThreadError and return.
        warn "unexpected status queue underflow - consumed elsewhere?"
      end

      def maybe_send_snapshots
        snapshots = []
        until snapshot_queue.empty?
          snapshots << snapshot_queue.shift(true)
        end
        if snapshots.any?
          begin
            snapshot_client.dispatch(INPUT_PATH, snapshots)
          rescue Error::AgentCommunicationError => exc
            raise if settings.internal_dynamic_instrumentation.propagate_all_exceptions
            # TODO
            puts "failed to send probe snapshots: #{exc.class}: #{exc}"
          end
        end
        snapshots.any?
      rescue ThreadError
        # Normally the queue should only be consumed in this method,
        # however if anyone consumes it elsewhere we don't want to block
        # while consuming it here. Rescue ThreadError and return.
        warn "unexpected snapshot queue underflow - consumed elsewhere?"
      end
    end
  end
end
