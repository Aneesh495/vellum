# frozen_string_literal: true

require_relative "polynomial"

module Vellum
  module Algebra
    # Polynomial interpolation routines: Lagrange basis interpolation,
    # Barycentric interpolation weights, and polynomial synthesis from sample points.
    module Interpolation
      class << self
        # Reconstructs the unique minimal degree polynomial passing through points (xs[i], ys[i])
        def lagrange_interpolate(xs, ys, field)
          raise ArgumentError, "Length mismatch: #{xs.length} xs vs #{ys.length} ys" unless xs.length == ys.length
          return Polynomial.zero(field) if xs.empty?
          return Polynomial.new(field, [ys.first]) if xs.length == 1

          n = xs.length
          result = Polynomial.zero(field)

          n.times do |i|
            next if ys[i].zero?

            # Compute basis polynomial L_i(X) = prod_{j != i} (X - xs[j]) / (xs[i] - xs[j])
            basis = Polynomial.one(field)
            denom = field.one

            n.times do |j|
              next if i == j

              # Multiply by (X - xs[j])
              term = Polynomial.new(field, [-xs[j], field.one])
              basis = basis * term
              denom = denom * (xs[i] - xs[j])
            end

            coeff = ys[i] * denom.inv
            scaled_basis = basis * coeff
            result = result + scaled_basis
          end

          result
        end

        # Evaluates interpolated polynomial at target point x using Barycentric formula:
        # P(x) = (sum w_j * y_j / (x - x_j)) / (sum w_j / (x - x_j))
        # where w_j = prod_{k != j} 1 / (x_j - x_k).
        def barycentric_evaluate(xs, ys, x, field)
          n = xs.length
          # Check if target x equals any sample point
          n.times do |i|
            return ys[i] if x == xs[i]
          end

          weights = compute_barycentric_weights(xs, field)

          num = field.zero
          den = field.zero

          n.times do |j|
            diff = x - xs[j]
            term = weights[j] * diff.inv
            num = num + (term * ys[j])
            den = den + term
          end

          num * den.inv
        end

        def compute_barycentric_weights(xs, field)
          n = xs.length
          weights = Array.new(n) { field.one }

          n.times do |j|
            n.times do |k|
              next if j == k

              weights[j] = weights[j] * (xs[j] - xs[k])
            end
            weights[j] = weights[j].inv
          end

          weights
        end
      end
    end
  end
end
