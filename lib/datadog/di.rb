# frozen_string_literal: true

require_relative 'di/error'
require_relative 'di/code_tracker'
require_relative 'di/component'
require_relative 'di/configuration'
require_relative 'di/extensions'
require_relative 'di/hook_manager'
require_relative 'di/probe'
require_relative 'di/probe_builder'
require_relative 'di/probe_notifier'
require_relative 'di/probe_notifier_worker'
require_relative 'di/remote'
require_relative 'di/remote_processor'
require_relative 'di/probe_status_client'
require_relative 'di/probe_snapshot_client'

module Datadog
  # Namespace for Datadog dynamic instrumentation.
  #
  # @api private
  module DI
    class << self
      def enabled?
        Datadog.configuration.internal_dynamic_instrumentation.enabled
      end
    end

    # Expose DI to global shared objects
    Extensions.activate!

    class << self
      attr_reader :code_tracker

      def activate_tracking!
        @code_tracker = CodeTracker.new
        code_tracker.start
      end

      def code_tracking_active?
        code_tracker&.active? || false
      end

      def component
        Datadog.send(:components).dynamic_instrumentation
      end
    end
  end
end
