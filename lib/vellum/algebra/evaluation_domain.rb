# frozen_string_literal: true

require_relative "polynomial"

module Vellum
  module Algebra
    # Multiplicative subgroup of roots of unity H = {omega^0, omega^1, ..., omega^(n-1)}
    # of size n = 2^k inside a prime field F_r.
    class EvaluationDomain
      attr_reader :field, :size, :log_size, :group_gen, :group_gen_inv

      def initialize(field, size)
        @field = field
        # Next power of 2
        @size = 1 << Math.log2([size, 1].max).ceil
        @log_size = Math.log2(@size).to_i

        raise FieldError, "Field 2-adicity (#{field.two_adicity}) insufficient for size #{@size}" if field.respond_to?(:two_adicity) && @log_size > field.two_adicity

        # Compute primitive n-th root of unity: omega = (2-adic root)^(2^(two_adicity - log_size))
        if field.respond_to?(:two_adic_root_of_unity)
          shift = field.two_adicity - @log_size
          @group_gen = field.two_adic_root_of_unity ** (1 << shift)
        else
          # Fallback: compute from field generator g^((p-1)/n)
          exp = (field.modulus - 1) / @size
          @group_gen = field.generator ** exp
        end

        @group_gen_inv = @group_gen.inv
      end

      # Returns all n elements [1, omega, omega^2, ..., omega^(n-1)]
      def elements
        @elements ||= begin
          elems = Array.new(@size)
          curr = @field.one
          @size.times do |i|
            elems[i] = curr
            curr = curr * @group_gen
          end
          elems
        end
      end

      # Evaluates the vanishing polynomial Z_H(X) = X^n - 1 at point x in O(log n)
      def evaluate_vanishing_polynomial(x)
        x_elem = x.is_a?(FieldElement) ? x : @field.element(x)
        (x_elem ** @size) - @field.one
      end

      # Vanishing polynomial as a full Polynomial instance: X^n - 1
      def vanishing_polynomial
        Polynomial.vanishing(@field, @size)
      end

      # Evaluates the i-th Lagrange basis polynomial L_i(X) at point x
      # L_i(x) = (omega_i / n) * (x^n - 1) / (x - omega_i)
      def evaluate_all_lagrange_at_point(x)
        x_elem = x.is_a?(FieldElement) ? x : @field.element(x)
        zh = evaluate_vanishing_polynomial(x_elem)
        n_inv = @field.element(@size).inv

        elems = elements
        # If x is one of the domain points omega_k, return kronecker delta
        elems.each_with_index do |omega_i, i|
          if x_elem == omega_i
            res = Array.new(@size) { @field.zero }
            res[i] = @field.one
            return res
          end
        end

        # Otherwise evaluate batch inverse of (x - omega_i)
        elems.map do |omega_i|
          denom = x_elem - omega_i
          (omega_i * n_inv * zh) / denom
        end
      end
    end
  end
end
