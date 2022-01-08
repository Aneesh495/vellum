# frozen_string_literal: true

require_relative "pairing_engine"
require_relative "../curves/bn254_g1"
require_relative "../curves/bn254_g2"
require_relative "../extensions/fp12"
require_relative "../extensions/fp6"
require_relative "../extensions/fp2"
require_relative "../fields/bn254_base"
require_relative "../fields/bn254_scalar"

module Vellum
  module Algebra
    module Pairing
      # Optimal Ate pairing engine over the BN254 / alt_bn128 curve.
      # Computes e(P, Q) where P in G1, Q in G2, and result in GT (Fp12).
      class BN254Pairing < PairingEngine
        # BN parameter u = 496566136792884961
        BN_U = 496566136792884961
        # 6*u + 2 in binary: 2979396820757309768
        # Bits from MSB to LSB:
        # 0b10100101001100010000000100000000100000000000000000000000000000000
        LOOP_PARAMETER = (6 * BN_U) + 2

        attr_reader :fp, :fp2, :fp6, :fp12, :g1, :g2

        def initialize
          @fp = Fields::BN254Base.instance
          @fp2 = Extensions::Fp2.new(@fp, -1)
          @fp6 = Extensions::Fp6.new(@fp2, :bn254)
          @fp12 = Extensions::Fp12.new(@fp6)
          @g1 = Curves::BN254G1.instance
          @g2 = Curves::BN254G2.instance
        end

        def self.instance
          @instance ||= new
        end

        # Multi-pairing: evaluates prod(e(P_i, Q_i))
        def multi_pairing(pairs)
          f = @fp12.one

          valid_pairs = pairs.reject { |p, q| p.infinity? || q.infinity? }
          return f if valid_pairs.empty?

          # Batch Miller loop
          f = miller_loop_batch(valid_pairs)

          # Single final exponentiation
          final_exponentiation(f)
        end

        # Evaluates Miller loop for multiple pairs simultaneously:
        # f = prod(MillerLoop(P_i, Q_i))
        def miller_loop_batch(pairs)
          f = @fp12.one
          bits = LOOP_PARAMETER.to_s(2)[1..].chars.map(&:to_i)

          # Affine representations
          norm_pairs = pairs.map do |p, q|
            [p.to_affine, q.to_affine, q.to_affine] # [P, Q, T (current accumulator point)]
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

          # BN specific additions at end of loop: Q1 = pi_q(Q), Q2 = -pi_q2(Q)
          norm_pairs.each do |entry|
            p_aff, q_aff, t_point = entry
            q1 = frobenius_q(q_aff)
            q2 = frobenius_q2(q_aff)
            neg_q2 = Curves::BN254G2.instance.point(q2.x, -q2.y)

            line1, t1 = line_add(t_point, q1, p_aff)
            f = mul_by_line(f, line1)

            line2, _ = line_add(t1, neg_q2, p_aff)
            f = mul_by_line(f, line2)
          end

          f
        end

        # Line function for point doubling on G2 evaluated at P in G1
        def line_double(t, p)
          # Tangent slope lambda = (3 * xT^2) / (2 * yT)
          x = t.x
          y = t.y
          lambda = (x * x * 3) / (y * 2)
          x_next = (lambda * lambda) - (x * 2)
          y_next = (lambda * (x - x_next)) - y
          new_t = @g2.point(x_next, y_next)

          # Line equation: yP - lambda*xP*w + (lambda*xT - yT)*w^3
          # Sparse Fp12 representation: [c0, c1] where c0 in Fp6, c1 in Fp6
          c_p = (lambda * x) - y
          line = {
            lambda: lambda,
            c_p: c_p,
            px: p.x,
            py: p.y
          }

          [line, new_t]
        end

        # Line function for point addition on G2 evaluated at P in G1
        def line_add(t, q, p)
          if t == q
            return line_double(t, p)
          end

          lambda = (q.y - t.y) / (q.x - t.x)
          x_next = (lambda * lambda) - t.x - q.x
          y_next = (lambda * (t.x - x_next)) - t.y
          new_t = @g2.point(x_next, y_next)

          c_p = (lambda * t.x) - t.y
          line = {
            lambda: lambda,
            c_p: c_p,
            px: p.x,
            py: p.y
          }

          [line, new_t]
        end

        # Multiplies Fp12 accumulator f by sparse line evaluation
        def mul_by_line(f, line)
          # Line evaluates to: py - (lambda * px)*w + c_p*w^3
          # Construct Fp12 line element
          # In Fp6: c0 + c1*v + c2*v^2
          c0 = @fp6.element([@fp2.element([line[:py], 0]), @fp2.zero, @fp2.zero])
          c1 = @fp6.element([-(line[:lambda] * line[:px]), line[:c_p], @fp2.zero])
          line_elem = @fp12.element([c0, c1])

          @fp12.multiply(f, line_elem)
        end

        # Frobenius map on G2: (x, y) -> (x^q * gamma12, y^q * gamma13)
        def frobenius_q(q)
          # In Fp2: (a0 + a1*u)^q = a0 - a1*u
          x_conj = @fp2.conjugate(q.x)
          y_conj = @fp2.conjugate(q.y)
          # Twist scaling constants
          gamma12 = @fp2.element([
            2157546887823998810692437658620188861621255537326888990142099306965868267213,
            10307601597875990266081772476023845805999709971454584474077709907682679680352
          ])
          gamma13 = @fp2.element([
            2821565182194536844548159561693502659359157864458866921386708692801427700054,
            11198109806351853963298656729084291277150115072625889120679840224610853912198
          ])
          @g2.point(x_conj * gamma12, y_conj * gamma13)
        end

        def frobenius_q2(q)
          gamma22 = @fp2.element([
            21888242871839275222246405745257275088696311157297823662689037894645226208582,
            0
          ])
          @g2.point(q.x * gamma22, -q.y)
        end

        # Final exponentiation: f^((q^12 - 1) / r)
        # Factorized into easy part f^( (q^6 - 1) * (q^2 + 1) ) and hard part f^((q^4 - q^2 + 1) / r).
        def final_exponentiation(f)
          return @fp12.one if f.zero?

          # Easy part 1: f^(q^6 - 1) = conj(f) * f^-1
          f_inv = f.inv
          f1 = @fp12.conjugate(f) * f_inv

          # Easy part 2: f1^(q^2 + 1) = frobenius_p2(f1) * f1
          f2 = frobenius_p2(f1) * f1

          # Hard part: f2^((q^4 - q^2 + 1) / r)
          hard_part(f2)
        end

        def frobenius_p2(f)
          # In Fp12: c0(x) + c1(x)*w
          a0, a1 = f.coeffs
          # Apply p^2 to Fp6 coeffs
          c0 = @fp6.element(a0.coeffs.map { |c| @fp2.conjugate(c) })
          c1 = @fp6.element(a1.coeffs.map { |c| @fp2.conjugate(c) })
          @fp12.element([c0, c1])
        end

        # Hard part using Beuchat et al. decomposition
        def hard_part(f)
          # Computes f^((q^4 - q^2 + 1) / r) via powers of u = BN_U
          exp = ((Fields::BN254Base::MODULUS**4) - (Fields::BN254Base::MODULUS**2) + 1) / Fields::BN254Scalar::MODULUS
          f ** exp
        end
      end
    end
  end
end
