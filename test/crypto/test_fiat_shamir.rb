# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/fiat_shamir"
require "vellum/algebra/fields/bn254_scalar"
require "vellum/algebra/curves/bn254_g1"

class TestFiatShamir < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @curve = Vellum::Algebra::Curves::BN254G1.instance
    @g = @curve.generator
  end

  def test_deterministic_transcript
    t1 = Vellum::Crypto::FiatShamir.new("test-session")
    t2 = Vellum::Crypto::FiatShamir.new("test-session")

    t1.absorb_bytes("msg", "hello world")
    t2.absorb_bytes("msg", "hello world")

    c1 = t1.squeeze_challenge("alpha", @field)
    c2 = t2.squeeze_challenge("alpha", @field)

    assert_equal c1, c2
    assert c1.is_a?(Vellum::Algebra::FieldElement)
  end

  def test_domain_separation
    t1 = Vellum::Crypto::FiatShamir.new("session-a")
    t2 = Vellum::Crypto::FiatShamir.new("session-b")

    c1 = t1.squeeze_challenge("challenge", @field)
    c2 = t2.squeeze_challenge("challenge", @field)

    refute_equal c1, c2, "Different session labels must produce different challenges"
  end

  def test_absorbing_elements_and_points
    t = Vellum::Crypto::FiatShamir.new("transcript")
    elem = @field.element(12345)
    t.absorb_element("input_scalar", elem)

    # Point absorption
    t.absorb_point("comm_a", @g)
    # Infinity point absorption
    t.absorb_point("comm_inf", @curve.infinity)

    challenge = t.squeeze_challenge("gamma", @field)
    refute_nil challenge
    assert challenge.is_a?(Vellum::Algebra::FieldElement)
  end

  def test_squeeze_multiple_challenges
    t = Vellum::Crypto::FiatShamir.new("transcript")
    t.absorb_bytes("seed", "deterministic-entropy")

    challenges = t.squeeze_challenges("beta", 4, @field)
    assert_equal 4, challenges.length
    assert_equal 4, challenges.uniq.length
  end
end
