# frozen_string_literal: true

require_relative "field_element"

module Vellum
  module Algebra
    # Dense univariate polynomial P(X) = sum(c_i * X^i) over an arbitrary field.
    class Polynomial
      attr_reader :field, :coeffs

      def initialize(field, coeffs)
        @field = field
        bf = field
        c = coeffs.map { |x| x.is_a?(FieldElement) || x.is_a?(ExtensionElement) ? x : bf.element(x) }
        # Strip trailing zeros
        while c.length > 1 && c.last.zero?
          c.pop
        end
        c = [field.zero] if c.empty?
        @coeffs = c
      end

      def degree
        return -1 if zero?

        @coeffs.length - 1
      end

      def [](idx)
        return @field.zero if idx >= @coeffs.length || idx.negative?

        @coeffs[idx]
      end

      def zero?
        @coeffs.length == 1 && @coeffs.first.zero?
      end

      def one?
        @coeffs.length == 1 && @coeffs.first.one?
      end

      # Horner's method for O(degree) polynomial evaluation at point x
      def evaluate(x)
        x_elem = x.is_a?(FieldElement) || x.is_a?(ExtensionElement) ? x : @field.element(x)
        return @field.zero if zero?

        res = @coeffs.last
        (@coeffs.length - 2).downto(0) do |i|
          res = (res * x_elem) + @coeffs[i]
        end
        res
      end
      alias call evaluate

      def +(other)
        o = coerce_poly(other)
        max_len = [@coeffs.length, o.coeffs.length].max
        new_coeffs = Array.new(max_len) do |i|
          self[i] + o[i]
        end
        Polynomial.new(@field, new_coeffs)
      end

      def -(other)
        o = coerce_poly(other)
        max_len = [@coeffs.length, o.coeffs.length].max
        new_coeffs = Array.new(max_len) do |i|
          self[i] - o[i]
        end
        Polynomial.new(@field, new_coeffs)
      end

      def -@
        Polynomial.new(@field, @coeffs.map(&:-@))
      end

      def *(other)
        if other.is_a?(Integer) || other.is_a?(FieldElement) || other.is_a?(ExtensionElement)
          return Polynomial.new(@field, @coeffs.map { |c| c * other })
        end

        o = coerce_poly(other)
        return Polynomial.zero(@field) if zero? || o.zero?

        if degree < 32 || o.degree < 32
          naive_multiply(o)
        else
          karatsuba_multiply(o)
        end
      end

      def /(other)
        divmod(other).first
      end

      def %(other)
        divmod(other).last
      end

      # Polynomial Euclidean division: self = q * other + r
      # Returns [q, r]
      def divmod(other)
        divisor = coerce_poly(other)
        raise ZeroDivisionError, "Polynomial division by zero" if divisor.zero?

        if degree < divisor.degree
          return [Polynomial.zero(@field), self]
        end

        rem_coeffs = @coeffs.dup
        div_deg = divisor.degree
        lead_inv = divisor.coeffs.last.inv
        quot_deg = degree - div_deg
        quot_coeffs = Array.new(quot_deg + 1) { @field.zero }

        (rem_coeffs.length - 1).downto(div_deg) do |i|
          lead = rem_coeffs[i]
          next if lead.zero?

          q = lead * lead_inv
          shift = i - div_deg
          quot_coeffs[shift] = q

          divisor.coeffs.each_with_index do |c, j|
            rem_coeffs[shift + j] -= (c * q)
          end
        end

        q_poly = Polynomial.new(@field, quot_coeffs)
        r_poly = Polynomial.new(@field, rem_coeffs[0...div_deg])
        [q_poly, r_poly]
      end

      def ==(other)
        return false unless other.is_a?(Polynomial)
        return false unless @field == other.field

        @coeffs == other.coeffs
      end
      alias eql? ==

      def hash
        [@field, @coeffs].hash
      end

      def to_s
        return "0" if zero?

        terms = []
        @coeffs.each_with_index do |c, i|
          next if c.zero?

          terms << if i.zero?
                     c.to_s
                   elsif i == 1
                     c.one? ? "X" : "#{c}*X"
                   else
                     c.one? ? "X^#{i}" : "#{c}*X^#{i}"
                   end
        end
        terms.reverse.join(" + ")
      end

      def inspect
        "Poly(#{to_s})"
      end

      def self.zero(field)
        new(field, [field.zero])
      end

      def self.one(field)
        new(field, [field.one])
      end

      # Vanishing polynomial Z_H(X) = X^n - 1 over a domain of size n
      def self.vanishing(field, n)
        coeffs = Array.new(n + 1) { field.zero }
        coeffs[0] = -field.one
        coeffs[n] = field.one
        new(field, coeffs)
      end

      private

      def coerce_poly(other)
        if other.is_a?(Polynomial)
          raise FieldError, "Polynomial field mismatch" unless @field == other.field
          other
        elsif other.is_a?(FieldElement) || other.is_a?(Integer) || other.is_a?(ExtensionElement)
          Polynomial.new(@field, [other])
        else
          raise TypeError, "Cannot coerce #{other.class} to Polynomial"
        end
      end

      def naive_multiply(other)
        res_deg = degree + other.degree
        res_coeffs = Array.new(res_deg + 1) { @field.zero }

        @coeffs.each_with_index do |c1, i|
          next if c1.zero?

          other.coeffs.each_with_index do |c2, j|
            res_coeffs[i + j] += (c1 * c2)
          end
        end

        Polynomial.new(@field, res_coeffs)
      end

      # Karatsuba divide-and-conquer multiplication
      def karatsuba_multiply(other)
        n = [degree, other.degree].max + 1
        m = n / 2

        low1 = Polynomial.new(@field, @coeffs[0...m] || [@field.zero])
        high1 = Polynomial.new(@field, @coeffs[m..] || [@field.zero])
        low2 = Polynomial.new(@field, other.coeffs[0...m] || [@field.zero])
        high2 = Polynomial.new(@field, other.coeffs[m..] || [@field.zero])

        z0 = low1 * low2
        z2 = high1 * high2
        z1 = ((low1 + high1) * (low2 + high2)) - z0 - z2

        # Combine: z2 * X^(2m) + z1 * X^m + z0
        shift_and_combine(z0, z1, z2, m)
      end

      def shift_and_combine(z0, z1, z2, m)
        total_len = [z0.coeffs.length, z1.coeffs.length + m, z2.coeffs.length + (2 * m)].max
        res = Array.new(total_len) { @field.zero }

        z0.coeffs.each_with_index { |c, i| res[i] += c }
        z1.coeffs.each_with_index { |c, i| res[i + m] += c }
        z2.coeffs.each_with_index { |c, i| res[i + (2 * m)] += c }

        Polynomial.new(@field, res)
      end
    end
  end
end
