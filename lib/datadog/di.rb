# frozen_string_literal: true

require_relative 'di/component'
require_relative 'di/configuration'
require_relative 'di/extensions'
require_relative 'di/hook'
require_relative 'di/probe'
require_relative 'di/probe_builder'
require_relative 'di/probe_notifier'
require_relative 'di/remote'
require_relative 'di/remote_processor'

module Datadog
  # Namespace for Datadog dynamic instrumentation
  module DI
    class << self
      def enabled?
        Datadog.configuration.internal_dynamic_instrumentation.enabled
      end
    end

    # Expose DI to global shared objects
    Extensions.activate!
  end
end
