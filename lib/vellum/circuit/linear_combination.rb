# frozen_string_literal: true

require_relative "variable"
require_relative "../algebra/field_element"

module Vellum
  module Circuit
    # Sparse symbolic linear combination of circuit variables:
    # sum(coeff_i * var_i).
    class LinearCombination
      attr_reader :field, :terms

      # terms is a Hash: Variable => FieldElement
      def initialize(field, terms = {})
        @field = field
        @terms = {}
        terms.each do |var, coeff|
          c = coeff.is_a?(Algebra::FieldElement) ? coeff : field.element(coeff)
          @terms[var] = c unless c.zero?
        end
      end

      def self.from_variable(var, field, coeff = 1)
        c = coeff.is_a?(Algebra::FieldElement) ? coeff : field.element(coeff)
        new(field, { var => c })
      end

      def self.constant(field, val, one_var)
        c = val.is_a?(Algebra::FieldElement) ? val : field.element(val)
        new(field, { one_var => c })
      end

      def +(other)
        o = coerce_lc(other)
        merged = @terms.dup
        o.terms.each do |var, coeff|
          curr = merged[var] || @field.zero
          new_coeff = curr + coeff
          if new_coeff.zero?
            merged.delete(var)
          else
            merged[var] = new_coeff
          end
        end
        LinearCombination.new(@field, merged)
      end

      def -(other)
        o = coerce_lc(other)
        merged = @terms.dup
        o.terms.each do |var, coeff|
          curr = merged[var] || @field.zero
          new_coeff = curr - coeff
          if new_coeff.zero?
            merged.delete(var)
          else
            merged[var] = new_coeff
          end
        end
        LinearCombination.new(@field, merged)
      end

      def -@
        negated = {}
        @terms.each do |var, coeff|
          negated[var] = -coeff
        end
        LinearCombination.new(@field, negated)
      end

      def *(scalar)
        s = scalar.is_a?(Algebra::FieldElement) ? scalar : @field.element(scalar)
        return LinearCombination.new(@field, {}) if s.zero?

        scaled = {}
        @terms.each do |var, coeff|
          val = coeff * s
          scaled[var] = val unless val.zero?
        end
        LinearCombination.new(@field, scaled)
      end

      def evaluate(witness)
        sum = @field.zero
        @terms.each do |var, coeff|
          val = witness[var] || witness[var.id]
          raise SynthesisError, "Unassigned wire: #{var}" if val.nil?

          elem = val.is_a?(Algebra::FieldElement) ? val : @field.element(val)
          sum = sum + (coeff * elem)
        end
        sum
      end

      def zero?
        @terms.empty?
      end

      def to_s
        return "0" if zero?

        @terms.map do |var, coeff|
          coeff.one? ? var.to_s : "#{coeff}*#{var}"
        end.join(" + ")
      end
      alias inspect to_s

      private

      def coerce_lc(other)
        if other.is_a?(LinearCombination)
          raise FieldError, "Field mismatch in LinearCombination" unless @field == other.field
          other
        elsif other.is_a?(Variable)
          LinearCombination.from_variable(other, @field)
        else
          raise TypeError, "Cannot coerce #{other.class} to LinearCombination"
        end
      end
    end
  end
end
