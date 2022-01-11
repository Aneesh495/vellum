# frozen_string_literal: true

module Vellum
  module Crypto
    module Rescue
      module Constants
        ROUNDS = 14

        class << self
          def mds_matrix(field, m)
            # Cauchy MDS matrix
            matrix = Array.new(m) { Array.new(m) }
            m.times do |i|
              m.times do |j|
                matrix[i][j] = field.element(i + m + j).inv
              end
            end
            matrix
          end

          def round_constants(field, m, num_rounds)
            total = 2 * m * num_rounds
            constants = []
            seed = (m << 8) | num_rounds
            curr = seed
            total.times do
              curr = ((curr * 2862933555777941757) + 3037000493) & 0xFFFFFFFFFFFFFFFF
              constants << field.element(curr % field.modulus)
            end
            constants
          end
        end
      end
    end
  end
end
