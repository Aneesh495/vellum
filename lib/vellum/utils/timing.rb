# frozen_string_literal: true

module Vellum
  module Utils
    # High-precision benchmarking and timing helper.
    module Timing
      class << self
        def measure
          t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          res = yield
          t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed_ms = (t1 - t0) * 1000.0
          [res, elapsed_ms]
        end
      end
    end
  end
end
