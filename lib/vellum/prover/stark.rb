# frozen_string_literal: true

require_relative "../crypto/merkle_tree"
require_relative "../crypto/fiat_shamir"
require_relative "../circuit/air/trace"
require_relative "../circuit/air/composition"

module Vellum
  module Prover
    # Transparent, post-quantum zero-knowledge STARK prover.
    # Implements execution trace Low-Degree Extension (LDE), deep composition polynomial,
    # and the Fast Reed-Solomon IOP of Proximity (FRI) multi-round folding protocol.
    class STARK
      class Proof
        attr_reader :trace_root, :comp_root, :fri_roots, :final_poly, :query_proofs

        def initialize(params)
          @trace_root = params[:trace_root]
          @comp_root = params[:comp_root]
          @fri_roots = params[:fri_roots]
          @final_poly = params[:final_poly]
          @query_proofs = params[:query_proofs]
        end
      end

      class << self
        def prove(trace, composition, num_queries = 8, blowup = 4)
          field = trace.field
          transcript = Crypto::FiatShamir.new("vellum-stark")

          # 1. Trace Low-Degree Extension (LDE) and Merkle commitment
          lde_data = trace.low_degree_extension(blowup, 3)
          lde_domain = lde_data[:domain]
          extended_cols = lde_data[:columns]
          lde_size = lde_domain.size

          # Leaves: combined register state at each point
          trace_leaves = Array.new(lde_size) do |i|
            extended_cols.map { |col| col[i] }
          end

          # Serialize leaf states for Merkle tree
          trace_leaf_hashes = trace_leaves.map do |row|
            Crypto::Blake2s.digest(row.map(&:to_s).join(":"))
          end

          trace_tree = Crypto::MerkleTree.new(trace_leaf_hashes, :blake2s)
          transcript.absorb_bytes("trace_root", trace_tree.root)

          # 2. Composition Polynomial & Commitment
          alpha = transcript.squeeze_challenge("alpha", field)
          beta = transcript.squeeze_challenge("beta", field)

          comp_poly = composition.build_composition_polynomial(alpha, beta)
          comp_evals = Algebra::NTT.coset_forward(comp_poly.coeffs, lde_domain, lde_data[:shift])

          comp_leaf_hashes = comp_evals.map do |val|
            Crypto::Blake2s.digest(val.to_s)
          end
          comp_tree = Crypto::MerkleTree.new(comp_leaf_hashes, :blake2s)
          transcript.absorb_bytes("comp_root", comp_tree.root)

          # 3. FRI (Fast Reed-Solomon IOP of Proximity) Folding
          curr_poly = comp_poly
          curr_domain = lde_domain
          fri_trees = []
          fri_roots = []

          # Fold until degree is small (< 4)
          while curr_poly.degree >= 4
            fri_challenge = transcript.squeeze_challenge("fri_challenge", field)

            # FRI fold: split into even and odd polynomials
            # f_next(X) = f_even(X) + challenge * f_odd(X)
            coeffs = curr_poly.coeffs
            even_coeffs = []
            odd_coeffs = []

            coeffs.each_with_index do |c, i|
              if i.even?
                even_coeffs << c
              else
                odd_coeffs << c
              end
            end

            poly_even = Algebra::Polynomial.new(field, even_coeffs)
            poly_odd = Algebra::Polynomial.new(field, odd_coeffs)
            curr_poly = poly_even + (poly_odd * fri_challenge)

            # Halve domain size for next round
            next_domain_size = [curr_domain.size / 2, 2].max
            curr_domain = Algebra::EvaluationDomain.new(field, next_domain_size)

            folded_evals = Algebra::NTT.forward(curr_poly.coeffs, curr_domain)
            folded_leaf_hashes = folded_evals.map { |v| Crypto::Blake2s.digest(v.to_s) }

            tree = Crypto::MerkleTree.new(folded_leaf_hashes, :blake2s)
            fri_trees << tree
            fri_roots << tree.root
            transcript.absorb_bytes("fri_root", tree.root)
          end

          # 4. Query Phase
          query_proofs = []
          num_queries.times do |q_idx|
            # Squeeze query index in LDE domain [0...lde_size]
            q_challenge = transcript.squeeze_challenge("query_#{q_idx}", field)
            idx = q_challenge.value % lde_size

            # Merkle inclusion proofs
            t_proof = trace_tree.prove(idx)
            c_proof = comp_tree.prove(idx)

            query_proofs << {
              index: idx,
              trace_leaf: trace_leaves[idx],
              trace_proof: t_proof.map { |s| s[:sibling] },
              comp_leaf: comp_evals[idx],
              comp_proof: c_proof.map { |s| s[:sibling] }
            }
          end

          Proof.new(
            trace_root: trace_tree.root,
            comp_root: comp_tree.root,
            fri_roots: fri_roots,
            final_poly: curr_poly,
            query_proofs: query_proofs
          )
        end
      end
    end
  end
end
