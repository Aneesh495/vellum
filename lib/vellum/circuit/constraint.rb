# frozen_string_literal: true

require_relative "linear_combination"

module Vellum
  module Circuit
    # Represents a single Rank-1 Constraint System (R1CS) constraint:
    # A * B = C
    # where A, B, and C are LinearCombination instances.
    class Constraint
      attr_reader :a, :b, :c, :label

      def initialize(a, b, c, label = nil)
        @a = a
        @b = b
        @c = c
        @label = label
      end

      # Checks if witness satisfies constraint: (A . w) * (B . w) == (C . w)
      def satisfied?(witness)
        val_a = @a.evaluate(witness)
        val_b = @b.evaluate(witness)
        val_c = @c.evaluate(witness)

        (val_a * val_b) == val_c
      end

      def evaluate_difference(witness)
        val_a = @a.evaluate(witness)
        val_b = @b.evaluate(witness)
        val_c = @c.evaluate(witness)

        (val_a * val_b) - val_c
      end

      def to_s
        lbl = @label ? "[#{@label}] " : ""
        "#{lbl}(#{@a}) * (#{@b}) == (#{@c})"
      end
      alias inspect to_s
    end
  end
end
