# frozen_string_literal: true

require_relative "r1cs"
require_relative "../algebra/evaluation_domain"
require_relative "../algebra/ntt"
require_relative "../algebra/polynomial"

module Vellum
  module Circuit
    # Quadratic Arithmetic Program (QAP) reduction from R1CS.
    # Transforms constraint matrices A, B, C into polynomials A_i(X), B_i(X), C_i(X)
    # over a roots of unity evaluation domain H, such that:
    # A(X) * B(X) - C(X) = H(X) * Z_H(X).
    class QAP
      attr_reader :r1cs, :domain, :poly_a, :poly_b, :poly_c

      def initialize(r1cs)
        @r1cs = r1cs
        @field = r1cs.field
        # Domain size m must be power of 2 >= num_constraints + 1 (for zero padding)
        min_size = [r1cs.num_constraints + 1, 2].max
        @domain = Algebra::EvaluationDomain.new(@field, min_size)
        build_polynomials!
      end

      # Computes witness polynomials A(X), B(X), C(X) and quotient H(X)
      # given witness assignment vector w.
      def witness_map(witness_vec)
        w = witness_vec.map { |v| v.is_a?(Algebra::FieldElement) ? v : @field.element(v) }
        n = @r1cs.num_variables

        # Linear combination of polynomials: A(X) = sum(w_i * A_i(X))
        a_poly = Algebra::Polynomial.zero(@field)
        b_poly = Algebra::Polynomial.zero(@field)
        c_poly = Algebra::Polynomial.zero(@field)

        n.times do |i|
          next if w[i].zero?

          a_poly = a_poly + (@poly_a[i] * w[i])
          b_poly = b_poly + (@poly_b[i] * w[i])
          c_poly = c_poly + (@poly_c[i] * w[i])
        end

        # P(X) = A(X) * B(X) - C(X)
        p_poly = (a_poly * b_poly) - c_poly

        # Vanishing polynomial Z_H(X) = X^m - 1
        zh = @domain.vanishing_polynomial

        # Exact division: H(X) = P(X) / Z_H(X)
        h_poly, rem = p_poly.divmod(zh)
        raise ConstraintError, "Witness does not satisfy QAP: remainder is #{rem}" unless rem.zero?

        {
          a: a_poly,
          b: b_poly,
          c: c_poly,
          h: h_poly,
          p: p_poly
        }
      end

      private

      def build_polynomials!
        m = @domain.size
        n = @r1cs.num_variables

        mat_a, mat_b, mat_c = @r1cs.build_matrices

        @poly_a = Array.new(n)
        @poly_b = Array.new(n)
        @poly_c = Array.new(n)

        # For each variable column, interpolate over domain H using iNTT
        n.times do |j|
          evals_a = Array.new(m) { @field.zero }
          evals_b = Array.new(m) { @field.zero }
          evals_c = Array.new(m) { @field.zero }

          @r1cs.num_constraints.times do |i|
            evals_a[i] = mat_a.get(i, j)
            evals_b[i] = mat_b.get(i, j)
            evals_c[i] = mat_c.get(i, j)
          end

          coeffs_a = Algebra::NTT.inverse(evals_a, @domain)
          coeffs_b = Algebra::NTT.inverse(evals_b, @domain)
          coeffs_c = Algebra::NTT.inverse(evals_c, @domain)

          @poly_a[j] = Algebra::Polynomial.new(@field, coeffs_a)
          @poly_b[j] = Algebra::Polynomial.new(@field, coeffs_b)
          @poly_c[j] = Algebra::Polynomial.new(@field, coeffs_c)
        end
      end
    end
  end
end
