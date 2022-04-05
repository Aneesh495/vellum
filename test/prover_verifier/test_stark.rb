# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/fields/goldilocks"
require "vellum/circuit/air/trace"
require "vellum/circuit/air/boundary"
require "vellum/circuit/air/composition"
require "vellum/prover/stark"
require "vellum/verifier/stark"

class TestSTARK < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::Goldilocks.instance
    @steps = 8
    @trace = Vellum::Circuit::AIR::Trace.new(@field, 2, @steps)

    # Simple geometric sequence: reg0 doubles each step (1, 2, 4, 8, 16, 32, 64, 128)
    val = 1
    @steps.times do |s|
      @trace.set(s, 0, val)
      @trace.set(s, 1, s)
      val *= 2
    end

    # Boundary: step 0 == 1, step 7 == 128
    b0 = Vellum::Circuit::AIR::Boundary.new(@field, @trace.domain, 0, 0, 1)
    b_term = Vellum::Circuit::AIR::Boundary.new(@field, @trace.domain, 7, 0, 128)

    @comp = Vellum::Circuit::AIR::Composition.new(@trace, [], [b0, b_term])
  end

  def test_stark_prove_and_verify
    proof = Vellum::Prover::STARK.prove(@trace, @comp, 4, 4)

    refute_nil proof
    refute_nil proof.trace_root
    refute_nil proof.comp_root
    assert proof.final_poly.degree < 4, "FRI final polynomial degree must be < 4"

    valid = Vellum::Verifier::STARK.verify(proof, @trace.domain, @field)
    assert valid, "Valid STARK proof must be accepted by transparent verifier"
  end

  def test_corrupted_stark_query_leaf_rejected
    proof = Vellum::Prover::STARK.prove(@trace, @comp, 4, 4)

    # Tamper with the first query proof leaf
    tampered_queries = proof.query_proofs.map(&:dup)
    tampered_queries[0][:trace_leaf] = tampered_queries[0][:trace_leaf].map { |x| x + @field.one }

    tampered_proof = Vellum::Prover::STARK::Proof.new(
      trace_root: proof.trace_root,
      comp_root: proof.comp_root,
      fri_roots: proof.fri_roots,
      final_poly: proof.final_poly,
      query_proofs: tampered_queries
    )

    valid = Vellum::Verifier::STARK.verify(tampered_proof, @trace.domain, @field)
    refute valid, "STARK proof with corrupted query leaf must be rejected"
  end

  def test_degree_bound_violation_rejected
    proof = Vellum::Prover::STARK.prove(@trace, @comp, 4, 4)

    # Artificial degree 5 final polynomial
    high_deg_poly = Vellum::Algebra::Polynomial.new(@field, [1, 1, 1, 1, 1, 1])

    tampered_proof = Vellum::Prover::STARK::Proof.new(
      trace_root: proof.trace_root,
      comp_root: proof.comp_root,
      fri_roots: proof.fri_roots,
      final_poly: high_deg_poly,
      query_proofs: proof.query_proofs
    )

    valid = Vellum::Verifier::STARK.verify(tampered_proof, @trace.domain, @field)
    refute valid, "STARK proof violating FRI final degree bound must be rejected"
  end
end
