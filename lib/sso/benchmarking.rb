module SSO
  # Helper to log results of benchmarks.
  module Benchmarking
    include ::SSO::Logging
    include ::SSO::Meter

    def benchmark(name: nil, metric: nil, &block)
      return unless block_given?
      result = nil
      seconds = Benchmark.realtime do
        result = block.call
      end
      milliseconds = (seconds * 1000).round
      debug { "#{name || metric || 'Benchmark'} took #{milliseconds}ms" }
      histogram key: metric, value: milliseconds if metric
      result
    end
  end
end
