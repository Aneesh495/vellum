# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BN254 / alt_bn128 scalar field Fr:
      # r = 21888242871839275222246405745257275088548364400416034343698204186575808495617
      # r - 1 has 2-adicity of 28 (i.e. (r-1) is divisible by 2^28).
      class BN254Scalar < PrimeField
        MODULUS = 21888242871839275222246405745257275088548364400416034343698204186575808495617
        TWO_ADICITY = 28
        # Multiplicative generator of order 2^28
        TWO_ADIC_ROOT_OF_UNITY = 19103219067921713944291392827692070036145651957329286315305642004821462161904

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end

        def self.zero
          instance.zero
        end

        def self.one
          instance.one
        end

        def self.random
          instance.random_element
        end

        # Generator of Fr*
        def generator
          element(5)
        end

        def two_adicity
          TWO_ADICITY
        end

        def two_adic_root_of_unity
          element(TWO_ADIC_ROOT_OF_UNITY)
        end
      end
    end
  end
end
