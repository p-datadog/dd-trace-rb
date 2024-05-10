# frozen_string_literal: true

require_relative 'debugger/component'
require_relative 'debugger/configuration'
require_relative 'debugger/extensions'
require_relative 'debugger/hook'
require_relative 'debugger/remote'

module Datadog
  # Namespace for Datadog Debugger instrumentation
  module Debugger
    class << self
      def enabled?
        Datadog.configuration.debugger.enabled
      end
    end

    # Expose Debugger to global shared objects
    Extensions.activate!
  end
end
