# frozen_string_literal: true

require_relative "bit"

module Vellum
  module DSL
    module Gadgets
      # In-circuit comparison and zero-test gadgets
      class ComparatorGadget
        # Returns boolean signal: 1 if signal == 0, else 0
        def self.is_zero(context, signal)
          is_zero_sig = context.signal("is_zero")
          inv_sig = context.signal("inv")

          # 1. signal * is_zero == 0
          context.r1cs.add_constraint(signal.lc, is_zero_sig.lc, Circuit::LinearCombination.new(context.field, {}), "is_zero_1")

          # 2. signal * inv == 1 - is_zero
          one_lc = Circuit::LinearCombination.constant(context.field, 1, context.r1cs.wire_allocator.one_variable)
          context.r1cs.add_constraint(signal.lc, inv_sig.lc, one_lc - is_zero_sig.lc, "is_zero_2")

          # 3. is_zero * (1 - is_zero) == 0
          is_zero_sig.assert_bit("is_zero_bool")

          # Witness generation hints
          is_zero_var = is_zero_sig.lc.terms.keys.first
          inv_var = inv_sig.lc.terms.keys.first

          context.add_witness_hint(is_zero_var) do |witness|
            val = signal.lc.evaluate(witness)
            val.zero? ? context.field.one : context.field.zero
          end

          context.add_witness_hint(inv_var) do |witness|
            val = signal.lc.evaluate(witness)
            val.zero? ? context.field.zero : val.inv
          end

          is_zero_sig
        end

        # Returns boolean signal: 1 if sig_a == sig_b, else 0
        def self.is_equal(context, sig_a, sig_b)
          diff = sig_a - sig_b
          is_zero(context, diff)
        end

        # Returns boolean signal: 1 if sig_a < sig_b (assuming values in 0..2^bits - 1)
        def self.less_than(context, sig_a, sig_b, bits = 64)
          # offset = 2^bits
          # diff = sig_a - sig_b + offset
          # If sig_a < sig_b, diff < 2^bits, so bit_bits == 0
          # If sig_a >= sig_b, diff >= 2^bits, so bit_bits == 1
          offset = 1 << bits
          diff = sig_a - sig_b + offset
          bit_signals = context.assert_range(diff, bits + 1)

          # High bit indicates sig_a >= sig_b
          ge_bit = bit_signals.last
          # less_than = 1 - ge_bit
          Signal.new(context, 1) - ge_bit
        end
      end
    end
  end
end
