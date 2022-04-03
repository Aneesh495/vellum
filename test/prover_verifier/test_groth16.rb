# frozen_string_literal: true

require_relative "../test_helper"
require "vellum"

class TestGroth16 < Minitest::Test
  def setup
    # Circuit: a * b = c, c * a = d (proves knowledge of a, b such that a^2 * b = d)
    @circuit = Vellum.circuit do
      a = private_input(:a)
      b = private_input(:b)
      d = public_input(:d)

      c = a * b
      res = c * a
      assert_equal(res, d, "power_relation")
    end

    @pk, @vk = @circuit.setup
  end

  def test_groth16_prove_and_verify
    # a = 3, b = 4 => c = 12 => d = 36
    inputs = { a: 3, b: 4, d: 36 }
    proof = @circuit.prove(@pk, inputs)

    refute_nil proof
    refute proof.a.infinity?
    refute proof.b.infinity?
    refute proof.c.infinity?

    # Verify with correct public input
    valid = @circuit.verify(@vk, [36], proof)
    assert valid, "Valid Groth16 proof must be accepted"
  end

  def test_tampered_public_input_rejected
    inputs = { a: 3, b: 4, d: 36 }
    proof = @circuit.prove(@pk, inputs)

    # Wrong public input 37 instead of 36
    valid = @circuit.verify(@vk, [37], proof)
    refute valid, "Groth16 proof with falsified public input must be rejected"
  end

  def test_tampered_proof_points_rejected
    inputs = { a: 3, b: 4, d: 36 }
    proof = @circuit.prove(@pk, inputs)

    # Corrupt A point by adding generator
    g1 = @pk.delta_g1.curve.generator
    corrupted_a = proof.a + g1
    tampered_proof = Vellum::Prover::Groth16::Proof.new(corrupted_a, proof.b, proof.c)

    valid = @circuit.verify(@vk, [36], tampered_proof)
    refute valid, "Groth16 proof with modified curve points must be rejected"
  end

  def test_zero_knowledge_blinding_uniqueness
    # Two proofs of the same witness should produce distinct points due to random blinding factors r, s
    inputs = { a: 3, b: 4, d: 36 }
    p1 = @circuit.prove(@pk, inputs)
    p2 = @circuit.prove(@pk, inputs)

    refute_equal p1.a, p2.a, "Randomized blinding must produce unique proof points"
    refute_equal p1.b, p2.b
    refute_equal p1.c, p2.c

    # Both must still verify
    assert @circuit.verify(@vk, [36], p1)
    assert @circuit.verify(@vk, [36], p2)
  end
end
