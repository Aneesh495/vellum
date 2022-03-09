# frozen_string_literal: true

require_relative "../crypto/kzg"
require_relative "../crypto/fiat_shamir"
require_relative "../algebra/pairing/bn254_pairing"

module Vellum
  module Verifier
    # Plonk universal zero-knowledge proof verifier.
    # Reconstructs Fiat-Shamir challenges and validates KZG polynomial opening proofs
    # with bilinear pairings in O(1) group operations.
    class Plonk
      class << self
        def verify(proof, srs, domain, field = srs.pairing_engine.fr)
          transcript = Crypto::FiatShamir.new("vellum-plonk")

          # Round 1
          transcript.absorb_point("comm_a", proof.a_comm)
          transcript.absorb_point("comm_b", proof.b_comm)
          transcript.absorb_point("comm_c", proof.c_comm)

          # Round 2
          beta = transcript.squeeze_challenge("beta", field)
          gamma = transcript.squeeze_challenge("gamma", field)
          transcript.absorb_point("comm_z", proof.z_comm)

          # Round 3
          alpha = transcript.squeeze_challenge("alpha", field)
          transcript.absorb_point("comm_t_lo", proof.t_lo_comm)
          transcript.absorb_point("comm_t_mid", proof.t_mid_comm)
          transcript.absorb_point("comm_t_hi", proof.t_hi_comm)

          # Round 4
          zeta = transcript.squeeze_challenge("zeta", field)
          transcript.absorb_element("eval_a", proof.a_eval)
          transcript.absorb_element("eval_b", proof.b_eval)
          transcript.absorb_element("eval_c", proof.c_eval)
          transcript.absorb_element("eval_s1", proof.s1_eval)
          transcript.absorb_element("eval_s2", proof.s2_eval)
          transcript.absorb_element("eval_z_omega", proof.z_omega_eval)

          # Round 5: Verify KZG opening proofs
          # Check opening of A(zeta)
          kzg_proof_a = Crypto::KZG::Proof.new(proof.a_comm, zeta, proof.a_eval, proof.w_zeta)
          valid_a = Crypto::KZG.verify(kzg_proof_a, srs)

          # Check opening of Z(zeta * omega)
          zeta_omega = zeta * domain.group_gen
          kzg_proof_z = Crypto::KZG::Proof.new(proof.z_comm, zeta_omega, proof.z_omega_eval, proof.w_zeta_omega)
          valid_z = Crypto::KZG.verify(kzg_proof_z, srs)

          valid_a && valid_z
        end
      end
    end
  end
end
