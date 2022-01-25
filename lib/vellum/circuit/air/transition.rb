# frozen_string_literal: true

require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module AIR
      # Evaluates transition constraints linking step t to step t+1 in a STARK trace.
      class Transition
        attr_reader :field, :domain, :evaluator

        def initialize(field, domain, &evaluator)
          @field = field
          @domain = domain
          @evaluator = evaluator
        end

        # Evaluates constraint C(curr_row, next_row)
        def evaluate(curr_row, next_row)
          @evaluator.call(curr_row, next_row)
        end

        # Vanishing polynomial for transitions: vanishes on H except the last step
        # Z_T(X) = (X^T - 1) / (X - omega^(T-1))
        def vanishing_polynomial
          zh = @domain.vanishing_polynomial
          last_step = @domain.elements.last
          divisor = Algebra::Polynomial.new(@field, [-last_step, @field.one])
          quot, _ = zh.divmod(divisor)
          quot
        end
      end
    end
  end
end
