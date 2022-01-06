# frozen_string_literal: true

module Vellum
  module Algebra
    # Multi-Scalar Multiplication (MSM) engine implementing Pippenger's bucket
    # algorithm and windowed multi-exponentiation for high-throughput linear combinations.
    # Evaluates Q = sum(scalars[i] * points[i]).
    module MSM
      class << self
        # Executes MSM using the best strategy for the problem dimensions
        def multi_scalar_mul(points, scalars)
          raise ArgumentError, "Length mismatch: #{points.length} points vs #{scalars.length} scalars" unless points.length == scalars.length
          return points.first.curve.infinity if points.empty?
          return points.first * scalars.first if points.length == 1

          if points.length < 16
            naive_msm(points, scalars)
          else
            pippenger(points, scalars)
          end
        end

        # Naive multi-scalar multiplication
        def naive_msm(points, scalars)
          res = points.first.curve.infinity
          points.each_with_index do |p, i|
            s = scalars[i].is_a?(FieldElement) ? scalars[i].value : scalars[i].to_i
            next if s.zero? || p.infinity?

            term = p * s
            res = res + term
          end
          res
        end

        # Pippenger's bucket method.
        # Divides scalar representation into c-bit windows and uses running bucket sums.
        def pippenger(points, scalars)
          curve = points.first.curve
          n = points.length
          return curve.infinity if n.zero?

          # Optimal window size c based on input size N
          c = optimal_window_size(n)
          num_buckets = (1 << c) - 1
          bit_len = scalars.first.is_a?(FieldElement) ? scalars.first.field.bit_length : 256
          num_windows = (bit_len + c - 1) / c

          # Convert all scalars to normalized non-negative integers
          scalar_ints = scalars.map do |s|
            val = s.is_a?(FieldElement) ? s.value : s.to_i
            val % (curve.order || 1)
          end

          acc = curve.infinity

          # Process windows from most significant to least significant
          (num_windows - 1).downto(0) do |w|
            # Double accumulator c times between windows
            c.times { acc = acc.double } unless acc.infinity?

            # Buckets 1..(2^c - 1)
            buckets = Array.new(num_buckets) { curve.infinity }

            # Distribute points into buckets according to their c-bit window slice
            n.times do |i|
              s = scalar_ints[i]
              chunk = (s >> (w * c)) & ((1 << c) - 1)
              next if chunk.zero?

              p = points[i]
              next if p.infinity?

              b_idx = chunk - 1
              buckets[b_idx] = buckets[b_idx].infinity? ? p : buckets[b_idx] + p
            end

            # Running sum accumulation:
            # sum(j * B_j) = B_k + (B_k + B_{k-1}) + ...
            window_sum = curve.infinity
            running_sum = curve.infinity

            (num_buckets - 1).downto(0) do |j|
              running_sum = running_sum + buckets[j] unless buckets[j].infinity?
              window_sum = window_sum + running_sum unless running_sum.infinity?
            end

            acc = acc + window_sum unless window_sum.infinity?
          end

          acc
        end

        private

        # Heuristic for optimal Pippenger window size
        def optimal_window_size(n)
          if n < 32
            3
          elsif n < 128
            4
          elsif n < 512
            5
          elsif n < 2048
            6
          elsif n < 8192
            7
          else
            8
          end
        end
      end
    end
  end
end
