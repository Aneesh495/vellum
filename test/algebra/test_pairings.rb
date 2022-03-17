# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/pairing/bn254_pairing"

class TestPairings < Minitest::Test
  def setup
    @engine = Vellum::Algebra::Pairing::BN254Pairing.instance
    @g1 = @engine.g1.generator
    @g2 = @engine.g2.generator
    @field = @engine.fr
  end

  def test_identity_pairings
    # e(inf, G2) == 1
    inf1 = @engine.g1.infinity
    inf2 = @engine.g2.infinity

    assert_equal @engine.fp12.one, @engine.pairing(inf1, @g2)
    assert_equal @engine.fp12.one, @engine.pairing(@g1, inf2)
    assert_equal @engine.fp12.one, @engine.pairing(inf1, inf2)
  end

  def test_non_degeneracy
    gt_elem = @engine.pairing(@g1, @g2)
    refute_equal @engine.fp12.one, gt_elem, "Pairing of generators must be non-degenerate"
  end

  def test_bilinearity
    a = 3
    b = 5

    p1 = @g1 * a
    q1 = @g2 * b

    # e(a*P, b*Q) == e(P, Q)^(a*b)
    pair_ab = @engine.pairing(p1, q1)

    pair_base = @engine.pairing(@g1, @g2)
    expected = pair_base**(a * b)

    assert_equal expected, pair_ab, "Pairing must satisfy bilinearity"
  end

  def test_check_pairing_identity
    # e(2*G1, 3*G2) * e(-6*G1, G2) == 1
    p1 = @g1 * 2
    q1 = @g2 * 3
    p2 = -(@g1 * 6)
    q2 = @g2

    valid = @engine.check_pairing_identity([
      [p1, q1],
      [p2, q2]
    ])

    assert valid, "Bilinear pairing identity must hold"
  end
end
