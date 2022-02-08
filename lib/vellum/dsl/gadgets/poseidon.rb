# frozen_string_literal: true

require_relative "../../crypto/poseidon/constants"

module Vellum
  module DSL
    module Gadgets
      # In-circuit Poseidon algebraic hash gadget.
      # Synthesizes exact R1CS constraints for power permutations x^5,
      # round constant additions, and MDS matrix diffusion layers.
      class PoseidonGadget
        def self.hash_2(context, left_sig, right_sig)
          hash(context, [left_sig, right_sig], rate: 2, capacity: 1)
        end

        def self.hash(context, input_signals, rate: 2, capacity: 1)
          field = context.field
          width = rate + capacity
          rf = Crypto::Poseidon::Constants::RF
          rp = Crypto::Poseidon::Constants::RP
          num_rounds = rf + rp

          round_constants = Crypto::Poseidon::Constants.round_constants(field, width, num_rounds)
          mds = Crypto::Poseidon::Constants.mds_matrix(field, width)

          # Initialize state signals
          state = Array.new(width) { Signal.new(context, 0) }
          input_signals.each_with_index do |sig, i|
            state[i] = sig if i < rate
          end

          half_rf = rf / 2
          const_idx = 0

          # 1. First half full rounds
          half_rf.times do
            state = add_constants(context, state, round_constants, const_idx, width)
            const_idx += width
            state = apply_full_sbox(context, state, width)
            state = apply_mds(context, state, mds, width)
          end

          # 2. Partial rounds
          rp.times do
            state = add_constants(context, state, round_constants, const_idx, width)
            const_idx += width
            state = apply_partial_sbox(context, state)
            state = apply_mds(context, state, mds, width)
          end

          # 3. Second half full rounds
          half_rf.times do
            state = add_constants(context, state, round_constants, const_idx, width)
            const_idx += width
            state = apply_full_sbox(context, state, width)
            state = apply_mds(context, state, mds, width)
          end

          state.first
        end

        private

        def self.add_constants(context, state, constants, offset, width)
          Array.new(width) do |i|
            state[i] + Signal.new(context, constants[offset + i])
          end
        end

        # In-circuit x^5: x2 = x * x, x4 = x2 * x2, x5 = x4 * x
        def self.sbox(context, x)
          x2 = x * x
          x4 = x2 * x2
          x4 * x
        end

        def self.apply_full_sbox(context, state, width)
          Array.new(width) { |i| sbox(context, state[i]) }
        end

        def self.apply_partial_sbox(context, state)
          new_state = state.dup
          new_state[0] = sbox(context, state[0])
          new_state
        end

        def self.apply_mds(context, state, mds, width)
          Array.new(width) do |i|
            terms = state.each_with_index.map do |s, j|
              s.lc * mds[i][j]
            end
            combined_lc = terms.reduce(Circuit::LinearCombination.new(context.field, {})) { |acc, t| acc + t }
            Signal.new(context, combined_lc)
          end
        end
      end
    end
  end
end
