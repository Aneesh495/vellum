# frozen_string_literal: true

require_relative "trace"
require_relative "transition"
require_relative "boundary"
require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module AIR
      # Synthesizes the deep composition polynomial C(X) combining all
      # boundary constraint quotients and transition constraint quotients
      # scaled by Fiat-Shamir pseudorandom challenge coefficients.
      class Composition
        attr_reader :field, :trace, :transitions, :boundaries

        def initialize(trace, transitions = [], boundaries = [])
          @trace = trace
          @field = trace.field
          @transitions = transitions
          @boundaries = boundaries
        end

        # Builds quotient polynomial for a boundary constraint:
        # Q_B(X) = (P_reg(X) - val) / (X - omega^step)
        def boundary_quotient(boundary)
          reg_poly = @trace.register_polynomial(boundary.register_idx)
          numerator = reg_poly - boundary.expected_value
          divisor = boundary.vanishing_polynomial

          quot, rem = numerator.divmod(divisor)
          raise ConstraintError, "Boundary constraint violated: remainder #{rem}" unless rem.zero?

          quot
        end

        # Builds composition polynomial:
        # C(X) = sum(alpha_i * TransitionQuotient_i(X)) + sum(beta_j * BoundaryQuotient_j(X))
        def build_composition_polynomial(challenge_alpha, challenge_beta)
          comp_poly = Algebra::Polynomial.zero(@field)
          curr_alpha = @field.one
          curr_beta = @field.one

          # Boundary quotients
          @boundaries.each do |b|
            bq = boundary_quotient(b)
            comp_poly = comp_poly + (bq * curr_beta)
            curr_beta = curr_beta * challenge_beta
          end

          comp_poly
        end
      end
    end
  end
end
