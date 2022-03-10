# frozen_string_literal: true

require_relative "evaluation_domain"
require_relative "polynomial"

module Vellum
  module Algebra
    # Fast Number Theoretic Transform (NTT) module implementing Cooley-Tukey
    # Radix-2 Decimation-In-Time (DIT) algorithm, bit-reversal permutation,
    # inverse NTT, and Coset-NTT for fast O(n log n) polynomial operations.
    module NTT
      class << self
        # Forward NTT: converts coefficient vector of length n = 2^k into
        # evaluations at [1, omega, omega^2, ..., omega^(n-1)].
        def forward(coeffs, domain)
          n = domain.size
          padded = coeffs + Array.new([0, n - coeffs.length].max) { domain.field.zero }
          a = padded[0...n].dup
          bit_reverse!(a)

          # Cooley-Tukey Radix-2 butterfly network
          len = 2
          while len <= n
            half = len / 2
            # Step generator: omega^(n / len)
            step_exp = n / len
            w_step = domain.group_gen ** step_exp

            (0...n).step(len) do |i|
              w = domain.field.one
              (0...half).each do |j|
                u = a[i + j]
                v = a[i + j + half] * w
                a[i + j] = u + v
                a[i + j + half] = u - v
                w = w * w_step
              end
            end
            len *= 2
          end

          a
        end

        # Inverse NTT: converts evaluation vector back to polynomial coefficients.
        def inverse(evals, domain)
          n = domain.size
          padded = evals + Array.new([0, n - evals.length].max) { domain.field.zero }
          a = padded[0...n].dup
          bit_reverse!(a)

          len = 2
          while len <= n
            half = len / 2
            step_exp = n / len
            w_step = domain.group_gen_inv ** step_exp

            (0...n).step(len) do |i|
              w = domain.field.one
              (0...half).each do |j|
                u = a[i + j]
                v = a[i + j + half] * w
                a[i + j] = u + v
                a[i + j + half] = u - v
                w = w * w_step
              end
            end
            len *= 2
          end

          # Normalization by 1/n
          n_inv = domain.field.element(n).inv
          a.map { |x| x * n_inv }
        end

        # Coset-NTT: evaluates polynomial on shifted coset g * H.
        # Scales c_i by g^i before running forward NTT.
        def coset_forward(coeffs, domain, shift)
          n = domain.size
          padded = coeffs + Array.new([0, n - coeffs.length].max) { domain.field.zero }
          curr_shift = domain.field.one

          scaled = padded[0...n].map do |c|
            res = c * curr_shift
            curr_shift = curr_shift * shift
            res
          end

          forward(scaled, domain)
        end

        # Inverse Coset-NTT: recovers polynomial coefficients from coset evaluations.
        def coset_inverse(evals, domain, shift)
          coeffs = inverse(evals, domain)
          shift_inv = shift.inv
          curr_inv = domain.field.one

          coeffs.map do |c|
            res = c * curr_inv
            curr_inv = curr_inv * shift_inv
            res
          end
        end

        # Fast O(n log n) polynomial multiplication via NTT
        def multiply_polynomials(poly_a, poly_b)
          deg_sum = poly_a.degree + poly_b.degree
          return Polynomial.zero(poly_a.field) if poly_a.zero? || poly_b.zero?

          domain_size = deg_sum + 1
          domain = EvaluationDomain.new(poly_a.field, domain_size)
          n = domain.size

          coeffs_a = poly_a.coeffs + Array.new(n - poly_a.coeffs.length) { poly_a.field.zero }
          coeffs_b = poly_b.coeffs + Array.new(n - poly_b.coeffs.length) { poly_a.field.zero }

          evals_a = forward(coeffs_a, domain)
          evals_b = forward(coeffs_b, domain)

          # Hadamard entry-wise product
          evals_c = evals_a.each_with_index.map { |ea, i| ea * evals_b[i] }

          coeffs_c = inverse(evals_c, domain)
          Polynomial.new(poly_a.field, coeffs_c[0..deg_sum])
        end

        # In-place bit-reversal permutation for length n = 2^k
        def bit_reverse!(arr)
          n = arr.length
          log_n = Math.log2(n).to_i

          (0...n).each do |i|
            rev = reverse_bits(i, log_n)
            if i < rev
              arr[i], arr[rev] = arr[rev], arr[i]
            end
          end
        end

        def reverse_bits(val, bits)
          res = 0
          bits.times do
            res = (res << 1) | (val & 1)
            val >>= 1
          end
          res
        end
      end
    end
  end
end
