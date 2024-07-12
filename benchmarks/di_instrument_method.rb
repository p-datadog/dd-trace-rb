# Used to quickly run benchmark under RSpec as part of the usual test suite, to validate it didn't bitrot
VALIDATE_BENCHMARK_MODE = ENV['VALIDATE_BENCHMARK'] == 'true'

return unless __FILE__ == $PROGRAM_NAME || VALIDATE_BENCHMARK_MODE

require 'benchmark/ips'
require 'datadog'
require_relative 'dogstatsd_reporter'

class DIInstrumentMethodBenchmark
  class Target
    def test_method
      # Perform some work to take up time
      SecureRandom.uuid
    end
    
    # This method must have an executable line as its first line,
    # otherwise line instrumentation won't work.
    # The code in this method should be identical to test_method above.
    # The two methods are separate so that instrumentation targets are
    # different, to avoid a false positive if line instrumemntation fails
    # to work and method instrumentation isn't cleared and continues to
    # invoke the callback.
    def test_method_for_line_probe
      SecureRandom.uuid
    end
  end
  
  def run_benchmark
    m = Target.instance_method(:test_method_for_line_probe)
    file, line = m.source_location
    
    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )

      # The idea of this benchmark is to test the overall cost of the Ruby VM calling these methods on every GC.
      # We're going as fast as possible (not realistic), but this should give us an upper bound for expected performance.
      x.report('no instrumentation') do
        Target.new.test_method
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    hook_manager = Datadog::DI::HookManager.new
    calls = 0
    hook_manager.hook_method('DIInstrumentMethodBenchmark::Target', 'test_method') do
      calls += 1
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )

      x.report('method instrumentation') do
        Target.new.test_method
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    if calls < 1
      raise "Method instrumentation did not work - callback was never invoked"
    end
    
    if calls < 1000 && !VALIDATE_BENCHMARK_MODE
      raise "Expected at least 1000 calls to the method, got #{calls}"
    end
    
    hook_manager.clear_hooks
    calls = 0
    hook_manager.hook_line(file, line + 1) do
      calls += 1
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )

      x.report('line instrumentation') do
        Target.new.test_method_for_line_probe
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    if calls < 1
      raise "Line instrumentation did not work - callback was never invoked"
    end
    
    if calls < 1000 && !VALIDATE_BENCHMARK_MODE
      raise "Expected at least 1000 calls to the method, got #{calls}"
    end
    
    require 'datadog/di/init'
    if defined?(DITarget)
      raise "DITarget is already defined, this should not happen"
    end
    require_relative 'di_target'
    unless defined?(DITarget)
      raise "DITarget is not defined, this should not happen"
    end
    
    m = DITarget.instance_method(:test_method_for_line_probe)
    targeted_file, targeted_line = m.source_location
    
    hook_manager.clear_hooks
    calls = 0
    hook_manager.hook_line(targeted_file, targeted_line + 1) do
      calls += 1
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )

      x.report('line instrumentation - targeted') do
        DITarget.new.test_method_for_line_probe
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    if calls < 1
      raise "Targeted line instrumentation did not work - callback was never invoked"
    end
    
    if calls < 1000 && !VALIDATE_BENCHMARK_MODE
      raise "Expected at least 1000 calls to the method, got #{calls}"
    end
    
    # Now, remove all installed hooks and check that the performance of
    # target code is approximately what it was prior to hook installation.
    
    hook_manager.clear_hooks
    calls = 0

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )
      
      # This benchmark should produce identical results to the
      # "no instrumentation" benchmark.
      x.report('method instrumentation - cleared') do
        Target.new.test_method
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    if calls != 0
      raise "Method instrumentation was not cleared (#{calls} calls recorded)"
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument_method')
      )

      # This benchmark should produce identical results to the
      # "no instrumentation" benchmark.
      x.report('line instrumentation - cleared') do
        Target.new.test_method_for_line_probe
      end

      x.save! 'di-instrument-method-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end
    
    if calls != 0
      raise "Line instrumentation was not cleared (#{calls} calls recorded)"
    end

  end

end

puts "Current pid is #{Process.pid}"

DIInstrumentMethodBenchmark.new.instance_exec do
  run_benchmark
end
