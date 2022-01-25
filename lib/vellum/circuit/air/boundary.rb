# frozen_string_literal: true

require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module AIR
      # Boundary constraints asserting register values at specific steps
      # (e.g. initial conditions at step 0, terminal output at step T-1).
      class Boundary
        attr_reader :field, :domain, :step, :register_idx, :expected_value

        def initialize(field, domain, step, register_idx, expected_value)
          @field = field
          @domain = domain
          @step = step
          @register_idx = register_idx
          @expected_value = expected_value.is_a?(Algebra::FieldElement) ? expected_value : field.element(expected_value)
        end

        # Point in domain corresponding to this step
        def step_point
          @domain.elements[@step]
        end

        # Vanishing polynomial: (X - step_point)
        def vanishing_polynomial
          Algebra::Polynomial.new(@field, [-step_point, @field.one])
        end

        def satisfied?(trace)
          actual = trace.get(@step, @register_idx)
          actual == @expected_value
        end
      end
    end
  end
end
