# Used to quickly run benchmark under RSpec as part of the usual test suite, to validate it didn't bitrot
VALIDATE_BENCHMARK_MODE = ENV['VALIDATE_BENCHMARK'] == 'true'

return unless __FILE__ == $PROGRAM_NAME || VALIDATE_BENCHMARK_MODE

require 'benchmark/ips'
require 'datadog'
require_relative 'dogstatsd_reporter'

class ConcurrencyPrimitivesBenchmark
  def run_benchmark
    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument')
      )

      mutex = Mutex.new

      x.report('mutex lock') do
        mutex.synchronize do
          # nothing
        end
      end

      x.save! 'concurrency-primitives-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument')
      )

      hash = Hash.new(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 9, i: 10)

      x.report('Hash access') do
        hash[:a]
      end

      x.save! 'concurrency-primitives-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end

    Benchmark.ips do |x|
      benchmark_time = VALIDATE_BENCHMARK_MODE ? { time: 0.01, warmup: 0 } : { time: 10, warmup: 2 }
      x.config(
        **benchmark_time,
        suite: report_to_dogstatsd_if_enabled_via_environment_variable(benchmark_name: 'di_instrument')
      )

      map = Concurrent::Map.new(a: 1, b: 2, c: 3, d: 4, e: 5, f: 6, g: 7, h: 9, i: 10)

      x.report('Concurrent::Map access') do
        map[:a]
      end

      x.save! 'concurrency-primitives-results.json' unless VALIDATE_BENCHMARK_MODE
      x.compare!
    end

  end

end

puts "Current pid is #{Process.pid}"

ConcurrencyPrimitivesBenchmark.new.instance_exec do
  run_benchmark
end
