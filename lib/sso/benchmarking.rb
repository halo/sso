module SSO
  # Helper to log results of benchmarks.
  module Benchmarking
    include ::SSO::Logging

    def benchmark(name, &block)
      result = nil
      seconds = Benchmark.realtime do
        result = block.call
      end
      info { "#{name} took #{(seconds * 1000).round}ms" }
      result
    end
  end
end
