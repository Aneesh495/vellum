# frozen_string_literal: true

require_relative "comparator"

module Vellum
  module DSL
    module Gadgets
      # Range proof gadgets asserting that secret values lie within [min, max]
      class RangeProofGadget
        # Asserts min_val <= signal <= max_val
        def self.assert_in_range(context, signal, min_val, max_val, bits = 64)
          # 1. signal - min_val >= 0
          diff_low = signal - Signal.new(context, min_val)
          context.assert_range(diff_low, bits, "range_low")

          # 2. max_val - signal >= 0
          diff_high = Signal.new(context, max_val) - signal
          context.assert_range(diff_high, bits, "range_high")
        end
      end
    end
  end
end
