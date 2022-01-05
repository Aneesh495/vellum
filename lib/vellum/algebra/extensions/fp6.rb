# frozen_string_literal: true

require_relative "../extension_field"

module Vellum
  module Algebra
    module Extensions
      # Sextic field extension Fp6 = Fp2[v]/(v^3 - xi).
      # Elements are represented as c0 + c1*v + c2*v^2 where c_i in Fp2.
      class Fp6 < ExtensionField
        attr_reader :curve_type

        def initialize(fp2_field, curve_type = :bn254)
          @curve_type = curve_type
          super(fp2_field, 3, nil)
        end

        def mul_by_xi(a)
          if @curve_type == :bn254
            base_field.mul_by_non_residue_bn254(a)
          else
            base_field.mul_by_non_residue_bls12381(a)
          end
        end

        def multiply(a, b)
          a0, a1, a2 = a.coeffs
          b0, b1, b2 = b.coeffs

          # Karatsuba-like cubic extension multiplication:
          # v0 = a0 * b0
          # v1 = a1 * b1
          # v2 = a2 * b2
          v0 = a0 * b0
          v1 = a1 * b1
          v2 = a2 * b2

          # c0 = v0 + xi * ((a1 + a2)*(b1 + b2) - v1 - v2)
          # c1 = (a0 + a1)*(b0 + b1) - v0 - v1 + xi * v2
          # c2 = (a0 + a2)*(b0 + b2) - v0 - v2 + v1
          t0 = mul_by_xi(((a1 + a2) * (b1 + b2)) - v1 - v2)
          c0 = v0 + t0

          t1 = mul_by_xi(v2)
          c1 = ((a0 + a1) * (b0 + b1)) - v0 - v1 + t1

          c2 = ((a0 + a2) * (b0 + b2)) - v0 - v2 + v1

          element([c0, c1, c2])
        end

        def square(a)
          multiply(a, a)
        end

        def inverse(a)
          a0, a1, a2 = a.coeffs

          # Chung-Hasan cubic extension inversion formulas:
          # d0 = a0^2 - xi * a1 * a2
          # d1 = xi * a2^2 - a0 * a1
          # d2 = a1^2 - a0 * a2
          # Delta = a0 * d0 + xi * (a2 * d1 + a1 * d2)
          d0 = (a0 * a0) - mul_by_xi(a1 * a2)
          d1 = mul_by_xi(a2 * a2) - (a0 * a1)
          d2 = (a1 * a1) - (a0 * a2)

          delta = (a0 * d0) + mul_by_xi((a2 * d1) + (a1 * d2))
          raise ZeroDivisionError, "Inverse of zero in Fp6" if delta.zero?

          delta_inv = delta.inv
          element([d0 * delta_inv, d1 * delta_inv, d2 * delta_inv])
        end
      end
    end
  end
end
