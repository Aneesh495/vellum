# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/kzg"
require "vellum/algebra/pairing/bn254_pairing"
require "vellum/algebra/polynomial"

class TestKZG < Minitest::Test
  def setup
    @engine = Vellum::Algebra::Pairing::BN254Pairing.instance
    @field = @engine.fr
    @srs = Vellum::Crypto::KZG.setup(8, @engine, 7)
  end

  def test_commit_open_and_verify
    # P(X) = 2X^2 + 5X + 3
    poly = Vellum::Algebra::Polynomial.new(@field, [3, 5, 2])
    comm = Vellum::Crypto::KZG.commit(poly, @srs)

    refute comm.infinity?, "Commitment must be a valid non-infinity curve point"

    # Open at z = 4: P(4) = 2(16) + 5(4) + 3 = 32 + 20 + 3 = 55
    z = @field.element(4)
    proof = Vellum::Crypto::KZG.open(poly, z, @srs)

    assert_equal @field.element(55), proof.y
    assert_equal comm, proof.commitment

    # Verify proof
    valid = Vellum::Crypto::KZG.verify(proof, @srs)
    assert valid, "Valid KZG proof must pass verification"
  end

  def test_corrupted_proof_rejected
    poly = Vellum::Algebra::Polynomial.new(@field, [1, 2, 3])
    proof = Vellum::Crypto::KZG.open(poly, @field.element(2), @srs)

    # Corrupt evaluation y
    corrupted_proof = Vellum::Crypto::KZG::Proof.new(
      proof.commitment,
      proof.z,
      proof.y + @field.one,
      proof.witness
    )

    valid = Vellum::Crypto::KZG.verify(corrupted_proof, @srs)
    refute valid, "Corrupted evaluation must fail verification"
  end

  def test_degree_exceeded_error
    # Degree 10 polynomial with degree 8 SRS
    coeffs = Array.new(11) { @field.element(1) }
    poly = Vellum::Algebra::Polynomial.new(@field, coeffs)

    assert_raises(ArgumentError) do
      Vellum::Crypto::KZG.commit(poly, @srs)
    end
  end

  def test_zero_polynomial_commitment
    zero_poly = Vellum::Algebra::Polynomial.zero(@field)
    comm = Vellum::Crypto::KZG.commit(zero_poly, @srs)

    assert comm.infinity?, "Zero polynomial commitment must equal curve infinity"
  end
end
