# frozen_string_literal: true

require_relative "../extension_field"

module Vellum
  module Algebra
    module Extensions
      # Dodecic field extension Fp12 = Fp6[w]/(w^2 - v).
      # Elements are d0 + d1*w where d0, d1 in Fp6 and w^2 = v.
      # Serves as the target group G_T for BN254 and BLS12-381 pairings.
      class Fp12 < ExtensionField
        def initialize(fp6_field)
          super(fp6_field, 2, nil)
        end

        # Multiply an Fp6 element by v:
        # (c0 + c1*v + c2*v^2)*v = xi*c2 + c0*v + c1*v^2
        def mul_by_v(a)
          c0, c1, c2 = a.coeffs
          xi_c2 = base_field.mul_by_xi(c2)
          base_field.element([xi_c2, c0, c1])
        end

        def multiply(a, b)
          a0, a1 = a.coeffs
          b0, b1 = b.coeffs

          # Karatsuba multiplication in Fp12:
          # v0 = a0 * b0
          # v1 = a1 * b1
          # c0 = v0 + v * v1
          # c1 = (a0 + a1)*(b0 + b1) - v0 - v1
          v0 = a0 * b0
          v1 = a1 * b1
          c0 = v0 + mul_by_v(v1)
          c1 = ((a0 + a1) * (b0 + b1)) - v0 - v1

          element([c0, c1])
        end

        def square(a)
          a0, a1 = a.coeffs
          # c0 = a0^2 + v * a1^2
          # c1 = 2 * a0 * a1
          v0 = a0 * a0
          v1 = a1 * a1
          c0 = v0 + mul_by_v(v1)
          c1 = (a0 * a1) * 2
          element([c0, c1])
        end

        def inverse(a)
          a0, a1 = a.coeffs
          # Norm in Fp6: N(a) = a0^2 - v * a1^2
          norm = (a0 * a0) - mul_by_v(a1 * a1)
          raise ZeroDivisionError, "Inverse of zero in Fp12" if norm.zero?

          norm_inv = norm.inv
          element([a0 * norm_inv, -a1 * norm_inv])
        end

        def conjugate(a)
          a0, a1 = a.coeffs
          element([a0, -a1])
        end

        # Cyclotomic squaring for elements in the cyclotomic subgroup
        # G_phi12 (crucial for accelerating final exponentiation)
        def cyclotomic_square(a)
          square(a)
        end
      end
    end
  end
end
