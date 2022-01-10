# frozen_string_literal: true

module Vellum
  module Crypto
    module Poseidon
      module SBox
        # Applies non-linear power permutation x^5 for prime fields
        # where gcd(5, p - 1) = 1 (BN254 and BLS12-381 scalar fields).
        def self.apply(element)
          x2 = element * element
          x4 = x2 * x2
          x4 * element
        end
      end
    end
  end
end
