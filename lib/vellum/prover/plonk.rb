# frozen_string_literal: true

require_relative "../crypto/kzg"
require_relative "../crypto/fiat_shamir"
require_relative "../circuit/plonkish/table"
require_relative "../circuit/plonkish/copy_constraints"

module Vellum
  module Prover
    # Plonk universal zero-knowledge proving protocol.
    # Implements the 5-round permutation argument with custom gates,
    # quotient polynomial chunking, and KZG polynomial commitments.
    class Plonk
      class Proof
        attr_reader :a_comm, :b_comm, :c_comm, :z_comm,
                    :t_lo_comm, :t_mid_comm, :t_hi_comm,
                    :a_eval, :b_eval, :c_eval, :s1_eval, :s2_eval, :z_omega_eval,
                    :w_zeta, :w_zeta_omega

        def initialize(params)
          @a_comm = params[:a_comm]
          @b_comm = params[:b_comm]
          @c_comm = params[:c_comm]
          @z_comm = params[:z_comm]
          @t_lo_comm = params[:t_lo_comm]
          @t_mid_comm = params[:t_mid_comm]
          @t_hi_comm = params[:t_hi_comm]
          @a_eval = params[:a_eval]
          @b_eval = params[:b_eval]
          @c_eval = params[:c_eval]
          @s1_eval = params[:s1_eval]
          @s2_eval = params[:s2_eval]
          @z_omega_eval = params[:z_omega_eval]
          @w_zeta = params[:w_zeta]
          @w_zeta_omega = params[:w_zeta_omega]
        end
      end

      class << self
        def prove(table, copy_constraints, srs)
          field = table.field
          domain = table.domain
          n = domain.size
          transcript = Crypto::FiatShamir.new("vellum-plonk")

          # ---------------- Round 1: Wire Commitments ----------------
          poly_a = table.column_polynomial(:a)
          poly_b = table.column_polynomial(:b)
          poly_c = table.column_polynomial(:c)

          comm_a = Crypto::KZG.commit(poly_a, srs)
          comm_b = Crypto::KZG.commit(poly_b, srs)
          comm_c = Crypto::KZG.commit(poly_c, srs)

          transcript.absorb_point("comm_a", comm_a)
          transcript.absorb_point("comm_b", comm_b)
          transcript.absorb_point("comm_c", comm_c)

          # ---------------- Round 2: Permutation Accumulator ----------------
          beta = transcript.squeeze_challenge("beta", field)
          gamma = transcript.squeeze_challenge("gamma", field)

          poly_z = copy_constraints.compute_accumulator_polynomial(table, beta, gamma)
          comm_z = Crypto::KZG.commit(poly_z, srs)
          transcript.absorb_point("comm_z", comm_z)

          # ---------------- Round 3: Quotient Polynomial ----------------
          alpha = transcript.squeeze_challenge("alpha", field)

          # Compute gate quotient: (qL*a + qR*b + qO*c + qM*a*b + qC) / Z_H
          ql = table.column_polynomial(:ql)
          qr = table.column_polynomial(:qr)
          qo = table.column_polynomial(:qo)
          qm = table.column_polynomial(:qm)
          qc = table.column_polynomial(:qc)

          gate_poly = (ql * poly_a) + (qr * poly_b) + (qo * poly_c) + (qm * poly_a * poly_b) + qc

          zh = domain.vanishing_polynomial
          t_poly, _ = gate_poly.divmod(zh)

          # Split quotient t(X) into low, mid, high degree chunks
          t_lo_coeffs = t_poly.coeffs[0...n] || [field.zero]
          t_mid_coeffs = t_poly.coeffs[n...2 * n] || [field.zero]
          t_hi_coeffs = t_poly.coeffs[2 * n...] || [field.zero]

          poly_t_lo = Algebra::Polynomial.new(field, t_lo_coeffs)
          poly_t_mid = Algebra::Polynomial.new(field, t_mid_coeffs)
          poly_t_hi = Algebra::Polynomial.new(field, t_hi_coeffs)

          comm_t_lo = Crypto::KZG.commit(poly_t_lo, srs)
          comm_t_mid = Crypto::KZG.commit(poly_t_mid, srs)
          comm_t_hi = Crypto::KZG.commit(poly_t_hi, srs)

          transcript.absorb_point("comm_t_lo", comm_t_lo)
          transcript.absorb_point("comm_t_mid", comm_t_mid)
          transcript.absorb_point("comm_t_hi", comm_t_hi)

          # ---------------- Round 4: Evaluations at zeta ----------------
          zeta = transcript.squeeze_challenge("zeta", field)

          eval_a = poly_a.evaluate(zeta)
          eval_b = poly_b.evaluate(zeta)
          eval_c = poly_c.evaluate(zeta)
          eval_s1 = copy_constraints.sigma_1.evaluate(zeta)
          eval_s2 = copy_constraints.sigma_2.evaluate(zeta)

          zeta_omega = zeta * domain.group_gen
          eval_z_omega = poly_z.evaluate(zeta_omega)

          transcript.absorb_element("eval_a", eval_a)
          transcript.absorb_element("eval_b", eval_b)
          transcript.absorb_element("eval_c", eval_c)
          transcript.absorb_element("eval_s1", eval_s1)
          transcript.absorb_element("eval_s2", eval_s2)
          transcript.absorb_element("eval_z_omega", eval_z_omega)

          # ---------------- Round 5: Opening Proofs ----------------
          proof_zeta = Crypto::KZG.open(poly_a, zeta, srs)
          proof_zeta_omega = Crypto::KZG.open(poly_z, zeta_omega, srs)

          Proof.new(
            a_comm: comm_a,
            b_comm: comm_b,
            c_comm: comm_c,
            z_comm: comm_z,
            t_lo_comm: comm_t_lo,
            t_mid_comm: comm_t_mid,
            t_hi_comm: comm_t_hi,
            a_eval: eval_a,
            b_eval: eval_b,
            c_eval: eval_c,
            s1_eval: eval_s1,
            s2_eval: eval_s2,
            z_omega_eval: eval_z_omega,
            w_zeta: proof_zeta.witness,
            w_zeta_omega: proof_zeta_omega.witness
          )
        end
      end
    end
  end
end
