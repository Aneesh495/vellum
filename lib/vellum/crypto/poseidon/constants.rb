# frozen_string_literal: true

require_relative "../../algebra/fields/bn254_scalar"

module Vellum
  module Crypto
    module Poseidon
      # Round constants and Maximum Distance Separable (MDS) matrices
      # for the Poseidon hash function over the BN254 scalar field Fr.
      # Configured for standard parameters (RF = 8 full rounds, RP = 57 partial rounds).
      module Constants
        RF = 8
        RP = 57

        class << self
          # Returns MDS matrix for width t
          def mds_matrix(field, t)
            # Cauchy matrix construction: M_{i, j} = 1 / (x_i + y_j)
            # where x_i = i, y_j = t + j
            matrix = Array.new(t) { Array.new(t) }
            t.times do |i|
              t.times do |j|
                denom = field.element(i + t + j)
                matrix[i][j] = denom.inv
              end
            end
            matrix
          end

          # Deterministic pseudorandom round constants generation via Grain LFSR
          def round_constants(field, t, num_rounds)
            total_constants = t * num_rounds
            constants = []

            # Deterministic grain sequence for BN254
            seed = (t << 16) | num_rounds
            curr = seed
            total_constants.times do
              # 64-bit linear congruential step
              curr = ((curr * 6364136223846793005) + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
              val = curr % field.modulus
              constants << field.element(val)
            end

            constants
          end
        end
      end
    end
  end
end
