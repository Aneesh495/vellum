# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # Goldilocks prime field:
      # p = 2^64 - 2^32 + 1 = 18446744069414584321
      # Designed specifically for ultra-fast STARKs with 2-adicity 32.
      # Fast reduction relies on 2^64 = 2^32 - 1 (mod p).
      class Goldilocks < PrimeField
        MODULUS = 18446744069414584321
        EPSILON = 0xFFFFFFFF
        TWO_ADICITY = 32
        # Primitive 2^32-th root of unity: 7^((p-1)/2^32) mod p
        TWO_ADIC_ROOT_OF_UNITY = 1753635133440165772

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end

        # Fast reduction for x < 2^128 using 2^64 = 2^32 - 1 (mod p)
        def fast_reduce(val)
          return val if val < MODULUS

          # x = x_hi * 2^64 + x_lo
          x_lo = val & 0xFFFFFFFFFFFFFFFF
          x_hi = val >> 64

          # x_hi * (2^32 - 1) = (x_hi << 32) - x_hi
          hi_32 = x_hi << 32
          diff = hi_32 - x_hi
          res = x_lo + diff

          # Normalize to [0, p)
          while res < 0
            res += MODULUS
          end
          res >= MODULUS ? (res % MODULUS) : res
        end

        def generator
          element(7)
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
