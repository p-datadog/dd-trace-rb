# frozen_string_literal: true

require_relative 'debugging/component'
require_relative 'debugging/configuration'
require_relative 'debugging/extensions'
require_relative 'debugging/hook'
require_relative 'debugging/probe'
require_relative 'debugging/remote'

module Datadog
  # Namespace for Datadog debugging instrumentation
  module Debugging
    class << self
      def enabled?
        Datadog.configuration.debugging.enabled
      end
    end

    # Expose debugging to global shared objects
    Extensions.activate!
  end
end
