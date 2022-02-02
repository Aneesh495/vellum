# frozen_string_literal: true

require_relative "../circuit/variable"
require_relative "../circuit/linear_combination"

module Vellum
  module DSL
    # High-level symbolic signal in the Vellum circuit DSL.
    # Wraps Variable or LinearCombination with arithmetic and comparison operator overloading.
    class Signal
      attr_reader :context, :lc

      def initialize(context, lc)
        @context = context
        @lc = if lc.is_a?(Circuit::LinearCombination)
                lc
              elsif lc.is_a?(Circuit::Variable)
                Circuit::LinearCombination.from_variable(lc, context.field)
              elsif lc.is_a?(Integer) || lc.is_a?(Algebra::FieldElement)
                Circuit::LinearCombination.constant(context.field, lc, context.r1cs.wire_allocator.one_variable)
              else
                raise TypeError, "Invalid signal target: #{lc.class}"
              end
      end

      def +(other)
        o = coerce_signal(other)
        Signal.new(@context, @lc + o.lc)
      end

      def -(other)
        o = coerce_signal(other)
        Signal.new(@context, @lc - o.lc)
      end

      def -@
        Signal.new(@context, -@lc)
      end

      # Non-linear multiplication creates an internal auxiliary wire and R1CS constraint
      def *(other)
        o = coerce_signal(other)

        # Allocate internal auxiliary signal for the product result
        aux_var = @context.r1cs.wire_allocator.allocate_internal("prod")
        aux_sig = Signal.new(@context, aux_var)

        # Add R1CS constraint: (self.lc) * (other.lc) == (aux.lc)
        @context.r1cs.add_constraint(@lc, o.lc, aux_sig.lc, "mul")

        # Register witness generator hint
        @context.add_witness_hint(aux_var) do |witness|
          val_a = @lc.evaluate(witness)
          val_b = o.lc.evaluate(witness)
          val_a * val_b
        end

        aux_sig
      end

      # Enforces equality constraint: self == other
      def assert_equal(other, label = nil)
        o = coerce_signal(other)
        one_lc = Circuit::LinearCombination.constant(@context.field, 1, @context.r1cs.wire_allocator.one_variable)
        # (self - other) * 1 == 0
        @context.r1cs.add_constraint(@lc - o.lc, one_lc, Circuit::LinearCombination.new(@context.field, {}), label || "assert_equal")
      end

      # Enforces boolean constraint: self * (1 - self) == 0
      def assert_bit(label = nil)
        one_lc = Circuit::LinearCombination.constant(@context.field, 1, @context.r1cs.wire_allocator.one_variable)
        @context.r1cs.add_constraint(@lc, one_lc - @lc, Circuit::LinearCombination.new(@context.field, {}), label || "assert_bit")
      end

      def to_s
        @lc.to_s
      end
      alias inspect to_s

      private

      def coerce_signal(other)
        if other.is_a?(Signal)
          other
        else
          Signal.new(@context, other)
        end
      end
    end
  end
end
