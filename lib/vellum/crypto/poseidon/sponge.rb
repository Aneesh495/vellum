# frozen_string_literal: true

require_relative "../sponge"
require_relative "constants"
require_relative "sbox"
require_relative "../../algebra/fields/bn254_scalar"

module Vellum
  module Crypto
    module Poseidon
      # High-performance zero-knowledge friendly hash function Poseidon
      # over prime finite fields.
      class Sponge < Crypto::Sponge
        attr_reader :rf, :rp, :num_rounds, :round_constants, :mds

        def initialize(field = Algebra::Fields::BN254Scalar.instance, rate = 2, capacity = 1)
          super(field, rate, capacity)
          @rf = Constants::RF
          @rp = Constants::RP
          @num_rounds = @rf + @rp
          @round_constants = Constants.round_constants(field, @width, @num_rounds)
          @mds = Constants.mds_matrix(field, @width)
        end

        def permute!
          half_rf = @rf / 2
          round_const_idx = 0

          # 1. First half of full rounds
          half_rf.times do
            add_round_constants(round_const_idx)
            round_const_idx += @width
            apply_full_sbox
            apply_mds
          end

          # 2. Partial rounds (S-box applied only to state[0])
          @rp.times do
            add_round_constants(round_const_idx)
            round_const_idx += @width
            apply_partial_sbox
            apply_mds
          end

          # 3. Second half of full rounds
          half_rf.times do
            add_round_constants(round_const_idx)
            round_const_idx += @width
            apply_full_sbox
            apply_mds
          end
        end

        private

        def add_round_constants(offset)
          @width.times do |i|
            @state[i] = @state[i] + @round_constants[offset + i]
          end
        end

        def apply_full_sbox
          @width.times do |i|
            @state[i] = SBox.apply(@state[i])
          end
        end

        def apply_partial_sbox
          @state[0] = SBox.apply(@state[0])
        end

        def apply_mds
          new_state = Array.new(@width) { @field.zero }

          @width.times do |i|
            sum = @field.zero
            @width.times do |j|
              sum = sum + (@mds[i][j] * @state[j])
            end
            new_state[i] = sum
          end

          @state = new_state
        end
      end

      class << self
        # Hashes an array of field elements using Poseidon
        def hash(elements, field: Algebra::Fields::BN254Scalar.instance, rate: 2, capacity: 1)
          sponge = Sponge.new(field, rate, capacity)
          sponge.absorb(elements)
          sponge.squeeze(1).first
        end

        # Fast 2-to-1 Poseidon hash (standard for Merkle tree nodes)
        def hash_2(left, right, field: Algebra::Fields::BN254Scalar.instance)
          hash([left, right], field: field, rate: 2, capacity: 1)
        end
      end
    end
  end
end
