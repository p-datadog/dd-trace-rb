# frozen_string_literal: true

# Load tracing
require_relative 'datadog/tracing'
require_relative 'datadog/tracing/contrib'

# Load other products (must follow tracing)
require_relative 'datadog/profiling'
require_relative 'datadog/appsec'
# Line probes will not work on Ruby < 2.6 because of lack of :script_compiled
# trace point. Only load DI on supported Ruby versions.
if RUBY_VERSION >= '2.6'
  require_relative 'datadog/di'
end
require_relative 'datadog/kit'

# Catch attempts to convert errors to "debug" log messages and log them
# as errors.
class Datadog::Core::Logger
  alias debug_original debug
  def debug(msg_or_progname = nil, &block)
    if block_given?
      msg = block.call
      if msg_or_progname
        msg = "#{msg_or_progname}: #{msg}"
      end
    else
      msg = msg_or_progname
    end
    if msg =~ /error|fail/i
      caller = binding.send(:caller).first
      error("** debug call converted to error: #{msg} (from #{caller})")
    else
      debug_original(msg)
    end
  end
end
