# frozen_string_literal: true

require_relative "field_element"

module Vellum
  module Algebra
    # Base class representing a field extension K = F[x]/(P(x)).
    # Coefficients are elements of the base field F.
    class ExtensionField
      attr_reader :base_field, :degree, :modulus_poly

      def initialize(base_field, degree, modulus_poly)
        @base_field = base_field
        @degree = degree
        @modulus_poly = modulus_poly # Array of coefficients [c0, c1, ..., c_{d-1}] where x^d = -sum(c_i x^i)
      end

      def element(coeffs)
        c = coeffs.is_a?(Array) ? coeffs : [coeffs]
        ExtensionElement.new(self, c)
      end

      def zero
        @zero ||= element(Array.new(@degree) { base_field.zero })
      end

      def one
        @one ||= element([base_field.one] + Array.new(@degree - 1) { base_field.zero })
      end

      def random_element
        coeffs = Array.new(@degree) { base_field.random_element }
        element(coeffs)
      end

      def ==(other)
        other.is_a?(ExtensionField) &&
          @base_field == other.base_field &&
          @degree == other.degree &&
          @modulus_poly == other.modulus_poly
      end
      alias eql? ==

      def hash
        [@base_field, @degree, @modulus_poly].hash
      end
    end

    # Element of an extension field represented as a polynomial sum(c_i * x^i)
    class ExtensionElement
      attr_reader :field, :coeffs

      def initialize(field, coeffs)
        @field = field
        bf = field.base_field
        raw_coeffs = coeffs.is_a?(Array) ? coeffs : [coeffs]
        c = raw_coeffs.map { |x| x.is_a?(FieldElement) || x.is_a?(ExtensionElement) ? x : bf.element(x) }
        # Pad or truncate to field degree
        @coeffs = c + Array.new([0, field.degree - c.length].max) { bf.zero }
        @coeffs = @coeffs[0...field.degree]
      end

      def [](idx)
        @coeffs[idx]
      end

      def +(other)
        o = coerce_element(other)
        res = @coeffs.each_with_index.map { |c, i| c + o.coeffs[i] }
        field.element(res)
      end

      def -(other)
        o = coerce_element(other)
        res = @coeffs.each_with_index.map { |c, i| c - o.coeffs[i] }
        field.element(res)
      end

      def -@
        field.element(@coeffs.map(&:-@))
      end

      def *(other)
        if other.is_a?(Integer) || other.is_a?(FieldElement)
          return field.element(@coeffs.map { |c| c * other })
        end

        o = coerce_element(other)
        # Degree-specific polynomial multiplication reduced modulo field.modulus_poly
        field.multiply(self, o)
      end

      def /(other)
        o = coerce_element(other)
        raise ZeroDivisionError, "Division by zero in extension field" if o.zero?

        self * o.inv
      end

      def **(exp)
        e = exp.to_i
        if e.negative?
          inv ** (-e)
        elsif e.zero?
          field.one
        else
          res = field.one
          base = self
          while e.positive?
            res = (res * base) if e.odd?
            base = (base * base) if e > 1
            e >>= 1
          end
          res
        end
      end

      def inv
        field.inverse(self)
      end

      def zero?
        @coeffs.all?(&:zero?)
      end

      def one?
        @coeffs[0].one? && @coeffs[1..].all?(&:zero?)
      end

      def conjugate
        field.respond_to?(:conjugate) ? field.conjugate(self) : self
      end
      alias frobenius conjugate

      def ==(other)
        return false unless other.is_a?(ExtensionElement) || other.is_a?(Integer) || other.is_a?(FieldElement)

        if other.is_a?(ExtensionElement)
          @field == other.field && @coeffs == other.coeffs
        elsif other.is_a?(Integer) || other.is_a?(FieldElement)
          @coeffs[0] == other && @coeffs[1..].all?(&:zero?)
        end
      end
      alias eql? ==

      def hash
        [@field, @coeffs].hash
      end

      def to_s
        terms = []
        @coeffs.each_with_index do |c, i|
          next if c.zero?

          terms << if i.zero?
                     c.to_s
                   elsif i == 1
                     c.one? ? "u" : "#{c}*u"
                   else
                     c.one? ? "u^#{i}" : "#{c}*u^#{i}"
                   end
        end
        terms.empty? ? "0" : terms.join(" + ")
      end

      def inspect
        "[#{@coeffs.map(&:to_s).join(', ')}]"
      end

      def coerce(other)
        if other.is_a?(Integer) || other.is_a?(FieldElement)
          [field.element([other]), self]
        else
          super
        end
      end

      private

      def coerce_element(other)
        if other.is_a?(ExtensionElement)
          raise FieldError, "Extension field mismatch" unless @field == other.field
          other
        elsif other.is_a?(FieldElement) || other.is_a?(Integer)
          field.element([other])
        else
          raise TypeError, "Cannot coerce #{other.class} to ExtensionElement"
        end
      end
    end
  end
end
