# frozen_string_literal: true

require_relative "../algebra/msm"
require_relative "../algebra/pairing/bn254_pairing"
require_relative "../circuit/qap"

module Vellum
  module Prover
    # Groth16 zero-knowledge proving system over pairing-friendly curves.
    # Features succinct 3-element proofs (A in G1, B in G2, C in G1)
    # with randomized witness blinding for perfect zero knowledge.
    class Groth16
      # Proving key containing SRS evaluations in G1 and G2
      class ProvingKey
        attr_reader :alpha_g1, :beta_g1, :beta_g2, :delta_g1, :delta_g2,
                    :a_query, :b_g1_query, :b_g2_query, :l_query, :h_query, :qap

        def initialize(params)
          @alpha_g1 = params[:alpha_g1]
          @beta_g1 = params[:beta_g1]
          @beta_g2 = params[:beta_g2]
          @delta_g1 = params[:delta_g1]
          @delta_g2 = params[:delta_g2]
          @a_query = params[:a_query]
          @b_g1_query = params[:b_g1_query]
          @b_g2_query = params[:b_g2_query]
          @l_query = params[:l_query]
          @h_query = params[:h_query]
          @qap = params[:qap]
        end
      end

      # Verifying key containing group elements for pairing identity check
      class VerifyingKey
        attr_reader :alpha_g1, :beta_g2, :gamma_g2, :delta_g2, :ic

        def initialize(params)
          @alpha_g1 = params[:alpha_g1]
          @beta_g2 = params[:beta_g2]
          @gamma_g2 = params[:gamma_g2]
          @delta_g2 = params[:delta_g2]
          @ic = params[:ic] # Array of G1 points for public inputs
        end

        def to_h
          {
            alpha_g1: [@alpha_g1.to_affine.x.to_s, @alpha_g1.to_affine.y.to_s],
            beta_g2: [
              [@beta_g2.to_affine.x.coeffs[0].to_s, @beta_g2.to_affine.x.coeffs[1].to_s],
              [@beta_g2.to_affine.y.coeffs[0].to_s, @beta_g2.to_affine.y.coeffs[1].to_s]
            ],
            gamma_g2: [
              [@gamma_g2.to_affine.x.coeffs[0].to_s, @gamma_g2.to_affine.x.coeffs[1].to_s],
              [@gamma_g2.to_affine.y.coeffs[0].to_s, @gamma_g2.to_affine.y.coeffs[1].to_s]
            ],
            delta_g2: [
              [@delta_g2.to_affine.x.coeffs[0].to_s, @delta_g2.to_affine.x.coeffs[1].to_s],
              [@delta_g2.to_affine.y.coeffs[0].to_s, @delta_g2.to_affine.y.coeffs[1].to_s]
            ],
            ic: @ic.map { |p| [p.to_affine.x.to_s, p.to_affine.y.to_s] }
          }
        end
      end

      # Succinct proof representation
      class Proof
        attr_reader :a, :b, :c

        def initialize(a, b, c)
          @a = a # G1
          @b = b # G2
          @c = c # G1
        end

        def to_h
          {
            a: [@a.to_affine.x.to_s, @a.to_affine.y.to_s],
            b: [
              [@b.to_affine.x.coeffs[0].to_s, @b.to_affine.x.coeffs[1].to_s],
              [@b.to_affine.y.coeffs[0].to_s, @b.to_affine.y.coeffs[1].to_s]
            ],
            c: [@c.to_affine.x.to_s, @c.to_affine.y.to_s]
          }
        end
      end

      class << self
        # Trusted setup generator: samples toxic waste (alpha, beta, gamma, delta, x)
        # and emits proving key and verifying key.
        def setup(r1cs, pairing_engine = Algebra::Pairing::BN254Pairing.instance)
          field = r1cs.field
          g1 = pairing_engine.g1.generator
          g2 = pairing_engine.g2.generator

          # Sample toxic secret trapdoors
          alpha = field.random_element
          beta = field.random_element
          gamma = field.random_element
          delta = field.random_element
          x = field.random_element

          qap = Circuit::QAP.new(r1cs)
          m = qap.domain.size
          num_vars = r1cs.num_variables
          num_pub = r1cs.num_public

          # Evaluate QAP polynomials at toxic x
          a_evals = qap.poly_a.map { |p| p.evaluate(x) }
          b_evals = qap.poly_b.map { |p| p.evaluate(x) }
          c_evals = qap.poly_c.map { |p| p.evaluate(x) }
          zh_at_x = qap.domain.evaluate_vanishing_polynomial(x)

          # Proving key elements
          alpha_g1 = g1 * alpha
          beta_g1 = g1 * beta
          beta_g2 = g2 * beta
          delta_g1 = g1 * delta
          delta_g2 = g2 * delta
          gamma_g2 = g2 * gamma

          a_query = a_evals.map { |val| g1 * val }
          b_g1_query = b_evals.map { |val| g1 * val }
          b_g2_query = b_evals.map { |val| g2 * val }

          delta_inv = delta.inv
          gamma_inv = gamma.inv

          # L_i(x) = (beta * A_i(x) + alpha * B_i(x) + C_i(x)) / delta for private wires i > l
          l_query = []
          (num_pub + 1...num_vars).each do |i|
            term = ((beta * a_evals[i]) + (alpha * b_evals[i]) + c_evals[i]) * delta_inv
            l_query << (g1 * term)
          end

          # H_j(x) = x^j * Z_H(x) / delta
          h_query = []
          curr_pow = field.one
          (m - 1).times do
            term = (curr_pow * zh_at_x) * delta_inv
            h_query << (g1 * term)
            curr_pow = curr_pow * x
          end

          # Verifying key IC elements:
          # IC_i = (beta * A_i(x) + alpha * B_i(x) + C_i(x)) / gamma for public wires 0..l
          ic = []
          (0..num_pub).each do |i|
            term = ((beta * a_evals[i]) + (alpha * b_evals[i]) + c_evals[i]) * gamma_inv
            ic << (g1 * term)
          end

          pk = ProvingKey.new(
            alpha_g1: alpha_g1,
            beta_g1: beta_g1,
            beta_g2: beta_g2,
            delta_g1: delta_g1,
            delta_g2: delta_g2,
            a_query: a_query,
            b_g1_query: b_g1_query,
            b_g2_query: b_g2_query,
            l_query: l_query,
            h_query: h_query,
            qap: qap
          )

          vk = VerifyingKey.new(
            alpha_g1: alpha_g1,
            beta_g2: beta_g2,
            gamma_g2: gamma_g2,
            delta_g2: delta_g2,
            ic: ic
          )

          [pk, vk]
        end

        # Synthesizes a zero-knowledge proof for witness vector w
        def prove(pk, witness_vec)
          qap_res = pk.qap.witness_map(witness_vec)
          field = pk.qap.domain.field
          num_pub = pk.qap.r1cs.num_public

          # Sample blinding factors r, s for perfect zero knowledge
          r = field.random_element
          s = field.random_element

          # A = alpha_G1 + sum(w_i * A_i) + r * delta_G1
          a_pts = pk.a_query
          a_acc = Algebra::MSM.multi_scalar_mul(a_pts, witness_vec)
          proof_a = pk.alpha_g1 + a_acc + (pk.delta_g1 * r)

          # B_G2 = beta_G2 + sum(w_i * B_i(G2)) + s * delta_G2
          b_pts_g2 = pk.b_g2_query
          b_acc_g2 = Algebra::MSM.multi_scalar_mul(b_pts_g2, witness_vec)
          proof_b = pk.beta_g2 + b_acc_g2 + (pk.delta_g2 * s)

          # B_G1 = beta_G1 + sum(w_i * B_i(G1)) + s * delta_G1
          b_pts_g1 = pk.b_g1_query
          b_acc_g1 = Algebra::MSM.multi_scalar_mul(b_pts_g1, witness_vec)
          b_g1 = pk.beta_g1 + b_acc_g1 + (pk.delta_g1 * s)

          # C = sum_{i > l} w_i * L_i + sum_j h_j * H_j + s*A + r*B_G1 - r*s*delta_G1
          priv_witness = witness_vec[num_pub + 1..] || []
          l_acc = Algebra::MSM.multi_scalar_mul(pk.l_query, priv_witness)

          h_coeffs = qap_res[:h].coeffs
          # Pad or trim h_coeffs to match h_query length
          h_len = [h_coeffs.length, pk.h_query.length].min
          h_pts = pk.h_query[0...h_len]
          h_scalars = h_coeffs[0...h_len]
          h_acc = Algebra::MSM.multi_scalar_mul(h_pts, h_scalars)

          proof_c = l_acc + h_acc + (proof_a * s) + (b_g1 * r) - (pk.delta_g1 * (r * s))

          Proof.new(proof_a, proof_b, proof_c)
        end
      end
    end
  end
end
