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
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'profiler_gc')
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
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'profiler_gc')
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
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'profiler_gc')
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
    
    hook_manager.clear_hooks

  end

end

puts "Current pid is #{Process.pid}"

def run_benchmark(&block)
  # Forking to avoid monkey-patching leaking between benchmarks
  pid = fork { block.call }
  _, status = Process.wait2(pid)

  raise "Benchmark failed with status #{status}" unless status.success?
end

DIInstrumentMethodBenchmark.new.instance_exec do
  run_benchmark
end
