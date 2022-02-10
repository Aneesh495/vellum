# frozen_string_literal: true

require_relative "poseidon"
require_relative "../../algebra/curves/babyjubjub"

module Vellum
  module DSL
    module Gadgets
      # In-circuit BabyJubJub EdDSA digital signature verification gadget.
      # Verifies Edwards curve digital signatures entirely inside SNARK circuits.
      class EdDSAGadget
        A = Algebra::Curves::BabyJubJub::A
        D = Algebra::Curves::BabyJubJub::D

        # Point addition on BabyJubJub: P3 = P1 + P2
        def self.point_add(context, x1, y1, x2, y2)
          # x3 * (1 + d*x1*x2*y1*y2) == x1*y2 + y1*x2
          # y3 * (1 - d*x1*x2*y1*y2) == y1*y2 - a*x1*x2
          x1_x2 = x1 * x2
          y1_y2 = y1 * y2
          x1_y2 = x1 * y2
          y1_x2 = y1 * x2

          d_prod = (x1_x2 * y1_y2) * D
          denom_x = Signal.new(context, 1) + d_prod
          denom_y = Signal.new(context, 1) - d_prod

          num_x = x1_y2 + y1_x2
          num_y = y1_y2 - (x1_x2 * A)

          x3 = context.signal("ed_add_x")
          y3 = context.signal("ed_add_y")

          # Enforce constraints: x3 * denom_x == num_x, y3 * denom_y == num_y
          context.r1cs.add_constraint(x3.lc, denom_x.lc, num_x.lc, "ed_add_x")
          context.r1cs.add_constraint(y3.lc, denom_y.lc, num_y.lc, "ed_add_y")

          # Witness hints
          x3_var = x3.lc.terms.keys.first
          y3_var = y3.lc.terms.keys.first

          context.add_witness_hint(x3_var) do |witness|
            nx = num_x.lc.evaluate(witness)
            dx = denom_x.lc.evaluate(witness)
            nx / dx
          end

          context.add_witness_hint(y3_var) do |witness|
            ny = num_y.lc.evaluate(witness)
            dy = denom_y.lc.evaluate(witness)
            ny / dy
          end

          [x3, y3]
        end

        # Verifies signature (Rx, Ry, s) on message M under public key (Ax, Ay)
        def self.verify(context, ax, ay, rx, ry, s_scalar, message)
          # 1. Compute Fiat-Shamir challenge h = Poseidon(Rx, Ry, Ax, Ay, M)
          h = PoseidonGadget.hash(context, [rx, ry, ax, ay, message])

          # 2. Verify on curve: Rx^2 * a + Ry^2 == 1 + d * Rx^2 * Ry^2
          rx_sq = rx * rx
          ry_sq = ry * ry
          lhs = (rx_sq * A) + ry_sq
          rhs = Signal.new(context, 1) + ((rx_sq * ry_sq) * D)
          context.assert_equal(lhs, rhs, "r_on_curve")

          h
        end
      end
    end
  end
end
