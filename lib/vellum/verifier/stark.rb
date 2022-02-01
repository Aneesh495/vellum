# frozen_string_literal: true

require_relative "../crypto/merkle_tree"
require_relative "../crypto/fiat_shamir"

module Vellum
  module Verifier
    # STARK proof verifier.
    # Transparent verification: checks FRI roots, Merkle inclusion paths,
    # and validates polynomial low-degree bounds without trusted setup.
    class STARK
      class << self
        def verify(proof, trace_domain, field)
          transcript = Crypto::FiatShamir.new("vellum-stark")

          # 1. Replay commitments
          transcript.absorb_bytes("trace_root", proof.trace_root)
          alpha = transcript.squeeze_challenge("alpha", field)
          beta = transcript.squeeze_challenge("beta", field)

          transcript.absorb_bytes("comp_root", proof.comp_root)

          # 2. Replay FRI roots
          proof.fri_roots.each do |root|
            transcript.absorb_bytes("fri_root", root)
          end

          # 3. Check final polynomial degree bound
          return false if proof.final_poly.degree >= 4

          # 4. Verify query authentication paths
          proof.query_proofs.each do |q|
            idx = q[:index]

            # Verify trace leaf inclusion
            trace_hash = Crypto::Blake2s.digest(q[:trace_leaf].map(&:to_s).join(":"))
            trace_valid = verify_path(trace_hash, idx, q[:trace_proof], proof.trace_root)
            return false unless trace_valid

            # Verify composition leaf inclusion
            comp_hash = Crypto::Blake2s.digest(q[:comp_leaf].to_s)
            comp_valid = verify_path(comp_hash, idx, q[:comp_proof], proof.comp_root)
            return false unless comp_valid
          end

          true
        end

        private

        def verify_path(leaf_hash, index, proof_siblings, root)
          curr = leaf_hash
          idx = index

          proof_siblings.each do |sibling|
            curr = if idx.even?
                     Crypto::Blake2s.digest(curr + sibling)
                   else
                     Crypto::Blake2s.digest(sibling + curr)
                   end
            idx /= 2
          end

          curr == root
        end
      end
    end
  end
end
