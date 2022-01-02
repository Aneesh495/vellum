# frozen_string_literal: true

module Vellum
  module Algebra
    # Represents an element of a finite field with complete operator overloading
    # and automatic coercion for integer arithmetic.
    class FieldElement
      include Comparable

      attr_reader :field, :value

      def initialize(field, value)
        @field = field
        @value = value % field.modulus
      end

      def +(other)
        other_val = coerce_value(other)
        field.element((@value + other_val) % field.modulus)
      end

      def -(other)
        other_val = coerce_value(other)
        field.element((@value - other_val) % field.modulus)
      end

      def *(other)
        other_val = coerce_value(other)
        field.element((@value * other_val) % field.modulus)
      end

      def /(other)
        other_elem = coerce_element(other)
        raise ZeroDivisionError, "Division by zero in field" if other_elem.zero?

        self * other_elem.inv
      end

      def -@
        field.element((field.modulus - @value) % field.modulus)
      end

      def **(exponent)
        exp = exponent.to_i
        if exp.negative?
          inv ** (-exp)
        elsif exp.zero?
          field.one
        else
          field.element(field.mod_pow(@value, exp))
        end
      end

      def inv
        raise ZeroDivisionError, "Inverse of zero does not exist" if zero?

        field.element(field.inv(@value))
      end

      def sqrt
        root = field.sqrt(@value)
        root ? field.element(root) : nil
      end

      def quadratic_residue?
        field.quadratic_residue?(@value)
      end

      def zero?
        @value.zero?
      end

      def one?
        @value == 1
      end

      def ==(other)
        return false unless other.is_a?(FieldElement) || other.is_a?(Integer)

        if other.is_a?(FieldElement)
          @field == other.field && @value == other.value
        else
          @value == (other % field.modulus)
        end
      end
      alias eql? ==

      def hash
        [@field.modulus, @value].hash
      end

      def <=>(other)
        return nil unless other.is_a?(FieldElement) && @field == other.field

        @value <=> other.value
      end

      def to_i
        @value
      end

      def to_s(base = 10)
        if base == 16
          "0x#{@value.to_s(16)}"
        else
          @value.to_s(base)
        end
      end

      def inspect
        "F_#{@field.modulus.to_s(16)[0..7]}...(#{to_s(16)})"
      end

      def to_bytes(endian = :little, length = nil)
        len = length || field.byte_length
        hex = @value.to_s(16).rjust(len * 2, "0")
        bytes = [hex].pack("H*")
        endian == :little ? bytes.reverse : bytes
      end

      def coerce(other)
        if other.is_a?(Integer)
          [field.element(other), self]
        else
          super
        end
      end

      private

      def coerce_value(other)
        if other.is_a?(FieldElement)
          raise FieldError, "Field mismatch: #{field} vs #{other.field}" unless @field == other.field
          other.value
        elsif other.is_a?(Integer)
          other % field.modulus
        else
          raise TypeError, "Cannot coerce #{other.class} to FieldElement"
        end
      end

      def coerce_element(other)
        if other.is_a?(FieldElement)
          raise FieldError, "Field mismatch: #{field} vs #{other.field}" unless @field == other.field
          other
        elsif other.is_a?(Integer)
          field.element(other)
        else
          raise TypeError, "Cannot coerce #{other.class} to FieldElement"
        end
      end
    end
  end
end
