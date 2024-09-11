$LOAD_PATH.unshift File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Thread.main.name = 'Thread.main' unless Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')

require 'pry'
require 'rspec/collection_matchers'
require 'rspec/wait'
require 'webmock/rspec'
require 'climate_control'

# Needed for calling JRuby.reference below
require 'jruby' if RUBY_ENGINE == 'jruby'

require 'datadog/core/encoding'
require 'datadog/tracing/tracer'
require 'datadog/tracing/span'

require 'support/core_helpers'
require 'support/faux_transport'
require 'support/faux_writer'
require 'support/loaded_gem'
require 'support/health_metric_helpers'
require 'support/log_helpers'
require 'support/network_helpers'
require 'support/object_space_helper'
require 'support/platform_helpers'
require 'support/span_helpers'
require 'support/spy_transport'
require 'support/synchronization_helpers'
require 'support/test_helpers'
require 'support/tracer_helpers'
require 'support/crashtracking_helpers'

begin
  # Ignore interpreter warnings from external libraries
  require 'warning'

  # Ignore warnings in Gem dependencies
  Gem.path.each do |path|
    Warning.ignore([:method_redefined, :not_reached, :unused_var, :arg_prefix], path)
    Warning.ignore(/circular require considered harmful/, path)
  end
rescue LoadError
  puts 'warning suppressing gem not available, external library warnings will be displayed'
end

WebMock.allow_net_connect!
WebMock.disable!

RSpec.configure do |config|
  config.include CoreHelpers
  config.include HealthMetricHelpers
  config.include LogHelpers
  config.include NetworkHelpers
  config.include LoadedGem
  config.extend  LoadedGem::Helpers
  config.include LoadedGem::Helpers
  config.include SpanHelpers
  config.include SynchronizationHelpers
  config.include TracerHelpers
  config.include TestHelpers::RSpec::Integration, :integration

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true
  #config.order = :random
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.example_status_persistence_file_path = 'tmp/example_status_persistence'

  # rspec-wait configuration
  config.wait_timeout = 5 # default timeout for `wait_for(...)`, in seconds
  config.wait_delay = 0.01 # default retry delay for `wait_for(...)`, in seconds

  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  config.before(:example, ractors: true) do
    unless config.filter_manager.inclusions[:ractors]
      skip 'Skipping ractor tests. Use rake spec:profiling:ractors or pass -t ractors to rspec to run.'
    end
  end

  # Check for leaky test resources.
  #
  # Execute this after the test has finished
  # teardown and mock verifications.
  #
  # Changing this to `config.after(:each)` would
  # put this code inside the test scope, interfering
  # with the test execution.
  #
  # rubocop:disable Style/GlobalVars
end

# Stores the caller thread backtrace,
# To allow for leaky threads to be traced
# back to their creation point.
module DatadogThreadDebugger
  # DEV: we have to use an explicit `block`, argument
  # instead of the implicit `yield` call, as calling
  # `yield` here crashes the Ruby VM in Ruby < 2.2.
  def initialize(*args, &block)
    @caller = caller
    wrapped = lambda do |*thread_args|
      block.call(*thread_args) # rubocop:disable Performance/RedundantBlockCall
    end
    wrapped.send(:ruby2_keywords) if wrapped.respond_to?(:ruby2_keywords, true)

    super(*args, &wrapped)
  end

  ruby2_keywords :initialize if respond_to?(:ruby2_keywords, true)
end

Thread.prepend(DatadogThreadDebugger)

require 'spec/support/thread_helpers'
# Enforce test time limit, to allow us to debug why some test runs get stuck in CI
if ENV.key?('CI')
  ThreadHelpers.with_leaky_thread_creation('Deadline thread') do
    Thread.new do
      Thread.current.name = 'spec_helper.rb CI debugging Deadline thread' unless RUBY_VERSION.start_with?('2.1.', '2.2.')

      sleep_time = 30 * 60 # 30 minutes
      sleep(sleep_time)

      warn "Test too longer than #{sleep_time}s to finish, aborting test run."
      warn 'Stack trace of all running threads:'

      Thread.list.select { |t| t.alive? && t != Thread.current }.each_with_index.map do |t, idx|
        backtrace = t.backtrace
        backtrace = ['(Not available)'] if backtrace.nil? || backtrace.empty?

        msg = "#{idx}: #{t} (#{t.class.name})",
              'Thread Backtrace:',
              backtrace.map { |l| "\t#{l}" }.join("\n"),
              "\n"

        warn(msg) rescue puts(msg)
      end

      Kernel.exit(1)
    end
  end
end

# Helper matchers
RSpec::Matchers.define_negated_matcher :not_be, :be

# The Ruby Timeout class uses a long-lived class-level thread that is never terminated.
# Creating it early here ensures tests that tests that check for leaking threads are not
# triggered by the creation of this thread.
#
# This has to be one once for the lifetime of this process, and was introduced in Ruby 3.1.
# Before 3.1, a thread was created and destroyed on every Timeout#timeout call.
Timeout.ensure_timeout_thread_created if Timeout.respond_to?(:ensure_timeout_thread_created)
