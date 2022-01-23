# frozen_string_literal: true

require_relative "../../algebra/ntt"
require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module Plonkish
      # Permutation argument for Plonkish copy constraints.
      # Enforces equality between shared wires across distinct gates and rows
      # using permutation polynomials sigma_1, sigma_2, sigma_3 and grand product accumulator Z(X).
      class CopyConstraints
        attr_reader :field, :domain, :sigma_1, :sigma_2, :sigma_3, :k1, :k2

        # k1, k2 are quadratic non-residue coset shifts
        def initialize(domain, k1 = 2, k2 = 3)
          @domain = domain
          @field = domain.field
          @k1 = @field.element(k1)
          @k2 = @field.element(k2)
        end

        # Computes identity permutation evaluations:
        # id_1 = omega^i, id_2 = k1 * omega^i, id_3 = k2 * omega^i
        def identity_permutations
          n = @domain.size
          omega_powers = @domain.elements

          id1 = omega_powers
          id2 = omega_powers.map { |w| w * @k1 }
          id3 = omega_powers.map { |w| w * @k2 }

          [id1, id2, id3]
        end

        # Generates permutation polynomials from copy pairs: array of [[row1, col1], [row2, col2]]
        def build_permutation_polynomials(copy_pairs)
          n = @domain.size
          id1, id2, id3 = identity_permutations

          sigma1_evals = id1.dup
          sigma2_evals = id2.dup
          sigma3_evals = id3.dup

          # Apply cycle swaps
          copy_pairs.each do |p1, p2|
            r1, c1 = p1
            r2, c2 = p2

            ref1 = [sigma1_evals, sigma2_evals, sigma3_evals][c1]
            ref2 = [sigma1_evals, sigma2_evals, sigma3_evals][c2]

            ref1[r1], ref2[r2] = ref2[r2], ref1[r1]
          end

          @sigma_1 = Algebra::Polynomial.new(@field, Algebra::NTT.inverse(sigma1_evals, @domain))
          @sigma_2 = Algebra::Polynomial.new(@field, Algebra::NTT.inverse(sigma2_evals, @domain))
          @sigma_3 = Algebra::Polynomial.new(@field, Algebra::NTT.inverse(sigma3_evals, @domain))

          [@sigma_1, @sigma_2, @sigma_3]
        end

        # Computes grand product polynomial Z(X) for permutation argument:
        # Z(omega^0) = 1
        # Z(omega^(i+1)) = Z(omega^i) * prod_{j=1}^3 (w_j + beta * id_j + gamma) / (w_j + beta * sigma_j + gamma)
        def compute_accumulator_polynomial(table, beta, gamma)
          n = @domain.size
          id1, id2, id3 = identity_permutations
          sigma1_evals = Algebra::NTT.forward(@sigma_1.coeffs, @domain)
          sigma2_evals = Algebra::NTT.forward(@sigma_2.coeffs, @domain)
          sigma3_evals = Algebra::NTT.forward(@sigma_3.coeffs, @domain)

          z_evals = Array.new(n) { @field.one }

          (0...n - 1).each do |i|
            a = table.wire_a[i]
            b = table.wire_b[i]
            c = table.wire_c[i]

            num = (a + (beta * id1[i]) + gamma) *
                  (b + (beta * id2[i]) + gamma) *
                  (c + (beta * id3[i]) + gamma)

            den = (a + (beta * sigma1_evals[i]) + gamma) *
                  (b + (beta * sigma2_evals[i]) + gamma) *
                  (c + (beta * sigma3_evals[i]) + gamma)

            z_evals[i + 1] = z_evals[i] * num * den.inv
          end

          coeffs = Algebra::NTT.inverse(z_evals, @domain)
          Algebra::Polynomial.new(@field, coeffs)
        end
      end
    end
  end
end
