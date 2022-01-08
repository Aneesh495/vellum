# frozen_string_literal: true

require_relative "pairing_engine"
require_relative "../curves/bls12_381_g1"
require_relative "../curves/bls12_381_g2"
require_relative "../extensions/fp12"
require_relative "../extensions/fp6"
require_relative "../extensions/fp2"
require_relative "../fields/bls12_381_base"
require_relative "../fields/bls12_381_scalar"

module Vellum
  module Algebra
    module Pairing
      # Optimal Ate pairing engine for the BLS12-381 curve.
      class BLS12381Pairing < PairingEngine
        # BLS parameter x = -0xd201000000010000
        BLS_X = -0xd201000000010000

        attr_reader :fp, :fp2, :fp6, :fp12, :g1, :g2

        def initialize
          @fp = Fields::BLS12381Base.instance
          @fp2 = Extensions::Fp2.new(@fp, -1)
          @fp6 = Extensions::Fp6.new(@fp2, :bls12_381)
          @fp12 = Extensions::Fp12.new(@fp6)
          @g1 = Curves::BLS12381G1.instance
          @g2 = Curves::BLS12381G2.instance
        end

        def self.instance
          @instance ||= new
        end

        def multi_pairing(pairs)
          f = @fp12.one
          valid_pairs = pairs.reject { |p, q| p.infinity? || q.infinity? }
          return f if valid_pairs.empty?

          f = miller_loop_batch(valid_pairs)
          final_exponentiation(f)
        end

        def miller_loop_batch(pairs)
          f = @fp12.one
          bits = BLS_X.abs.to_s(2)[1..].chars.map(&:to_i)

          norm_pairs = pairs.map do |p, q|
            [p.to_affine, q.to_affine, q.to_affine]
          end

          bits.each do |bit|
            f = @fp12.square(f)

            norm_pairs.each do |entry|
              p_aff, _, t_point = entry
              line, new_t = line_double(t_point, p_aff)
              entry[2] = new_t
              f = mul_by_line(f, line)
            end

            if bit == 1
              norm_pairs.each do |entry|
                p_aff, q_aff, t_point = entry
                line, new_t = line_add(t_point, q_aff, p_aff)
                entry[2] = new_t
                f = mul_by_line(f, line)
              end
            end
          end

          f
        end

        def line_double(t, p)
          x = t.x
          y = t.y
          lambda = (x * x * 3) / (y * 2)
          x_next = (lambda * lambda) - (x * 2)
          y_next = (lambda * (x - x_next)) - y
          new_t = @g2.point(x_next, y_next)

          c_p = (lambda * x) - y
          line = { lambda: lambda, c_p: c_p, px: p.x, py: p.y }
          [line, new_t]
        end

        def line_add(t, q, p)
          if t == q
            return line_double(t, p)
          end

          lambda = (q.y - t.y) / (q.x - t.x)
          x_next = (lambda * lambda) - t.x - q.x
          y_next = (lambda * (t.x - x_next)) - t.y
          new_t = @g2.point(x_next, y_next)

          c_p = (lambda * t.x) - t.y
          line = { lambda: lambda, c_p: c_p, px: p.x, py: p.y }
          [line, new_t]
        end

        def mul_by_line(f, line)
          c0 = @fp6.element([@fp2.element([line[:py], 0]), @fp2.zero, @fp2.zero])
          c1 = @fp6.element([-(line[:lambda] * line[:px]), line[:c_p], @fp2.zero])
          line_elem = @fp12.element([c0, c1])
          @fp12.multiply(f, line_elem)
        end

        def final_exponentiation(f)
          return @fp12.one if f.zero?

          # Easy part: f^((q^6 - 1)*(q^2 + 1))
          f_inv = f.inv
          f1 = @fp12.conjugate(f) * f_inv

          a0, a1 = f1.coeffs
          c0 = @fp6.element(a0.coeffs.map { |c| @fp2.conjugate(c) })
          c1 = @fp6.element(a1.coeffs.map { |c| @fp2.conjugate(c) })
          f2 = @fp12.element([c0, c1]) * f1

          # Hard part: f2^((q^4 - q^2 + 1) / r)
          exp = ((Fields::BLS12381Base::MODULUS**4) - (Fields::BLS12381Base::MODULUS**2) + 1) / Fields::BLS12381Scalar::MODULUS
          f2 ** exp
        end
      end
    end
  end
end
