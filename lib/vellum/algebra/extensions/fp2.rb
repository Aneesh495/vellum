# frozen_string_literal: true

require_relative "../extension_field"

module Vellum
  module Algebra
    module Extensions
      # Quadratic field extension Fp2 = Fp[u]/(u^2 - beta).
      # For BN254 and BLS12-381, beta = -1 (so u^2 = -1).
      class Fp2 < ExtensionField
        attr_reader :non_residue

        def initialize(base_field, non_residue = -1)
          @non_residue = base_field.element(non_residue)
          super(base_field, 2, [@non_residue])
        end

        def multiply(a, b)
          a0, a1 = a.coeffs
          b0, b1 = b.coeffs

          # Karatsuba multiplication in Fp2:
          # v0 = a0 * b0
          # v1 = a1 * b1
          # c0 = v0 + beta * v1
          # c1 = (a0 + a1)*(b0 + b1) - v0 - v1
          v0 = a0 * b0
          v1 = a1 * b1
          c0 = v0 + (v1 * @non_residue)
          c1 = ((a0 + a1) * (b0 + b1)) - v0 - v1

          element([c0, c1])
        end

        def square(a)
          a0, a1 = a.coeffs
          # (a0 + a1*u)^2 = a0^2 + beta*a1^2 + 2*a0*a1*u
          v0 = a0 * a0
          v1 = a1 * a1
          c0 = v0 + (v1 * @non_residue)
          c1 = (a0 * a1) * 2
          element([c0, c1])
        end

        def inverse(a)
          a0, a1 = a.coeffs
          # Norm N(a) = a0^2 - beta*a1^2
          # a^-1 = (a0 - a1*u) / N(a)
          norm = (a0 * a0) - (a1 * a1 * @non_residue)
          raise ZeroDivisionError, "Inverse of zero in Fp2" if norm.zero?

          norm_inv = norm.inv
          element([a0 * norm_inv, -a1 * norm_inv])
        end

        def conjugate(a)
          a0, a1 = a.coeffs
          element([a0, -a1])
        end

        # Multiply by non-residue xi for constructing higher extensions
        # In BN254: xi = 9 + u
        def mul_by_non_residue_bn254(a)
          # (a0 + a1*u) * (9 + u) = (9*a0 - a1) + (a0 + 9*a1)*u (since u^2 = -1)
          a0, a1 = a.coeffs
          c0 = (a0 * 9) - a1
          c1 = a0 + (a1 * 9)
          element([c0, c1])
        end

        # In BLS12-381: xi = (u + 1)
        def mul_by_non_residue_bls12381(a)
          # (a0 + a1*u) * (1 + u) = (a0 - a1) + (a0 + a1)*u
          a0, a1 = a.coeffs
          c0 = a0 - a1
          c1 = a0 + a1
          element([c0, c1])
        end
      end
    end
  end
end
