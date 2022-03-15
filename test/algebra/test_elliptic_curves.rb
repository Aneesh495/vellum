# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/curves/bn254_g1"
require "vellum/algebra/curves/bn254_g2"
require "vellum/algebra/curves/bls12_381_g1"
require "vellum/algebra/curves/bls12_381_g2"
require "vellum/algebra/curves/babyjubjub"

class TestEllipticCurves < Minitest::Test
  def setup
    @bn_g1 = Vellum::Algebra::Curves::BN254G1.instance
    @bn_g2 = Vellum::Algebra::Curves::BN254G2.instance
    @bls_g1 = Vellum::Algebra::Curves::BLS12381G1.instance
    @bls_g2 = Vellum::Algebra::Curves::BLS12381G2.instance
    @bjj = Vellum::Algebra::Curves::BabyJubJub.instance
  end

  def test_bn254_g1_point_arithmetic
    g = @bn_g1.generator
    assert @bn_g1.on_curve?(g), "Generator must lie on BN254 G1"

    # Identity
    inf = @bn_g1.infinity
    assert_equal g, g + inf
    assert_equal inf, g + (-g)

    # Doubling vs Addition
    g2_add = g + g
    g2_mul = g * 2
    assert_equal g2_add, g2_mul

    # Associativity: (g + 2g) + 3g == g + (2g + 3g)
    g2 = g * 2
    g3 = g * 3
    assert_equal (g + g2) + g3, g + (g2 + g3)

    # Subgroup order: order * g == inf
    order = @bn_g1.order
    assert (g * order).infinity?, "Scalar multiplication by subgroup order must yield infinity"
  end

  def test_bn254_g2_point_arithmetic
    g2 = @bn_g2.generator
    assert @bn_g2.on_curve?(g2), "Generator must lie on BN254 G2"

    doubled = g2 + g2
    assert_equal doubled, g2 * 2
  end

  def test_bls12_381_g1_point_arithmetic
    g = @bls_g1.generator
    assert @bls_g1.on_curve?(g), "Generator must lie on BLS12-381 G1"

    assert_equal g + g, g * 2
    order = @bls_g1.order
    assert (g * order).infinity?
  end

  def test_babyjubjub_twisted_edwards_arithmetic
    g = @bjj.generator
    b = @bjj.base8

    assert @bjj.on_curve?(g), "Generator must lie on BabyJubJub"
    assert @bjj.on_curve?(b), "Base8 point must lie on BabyJubJub"

    # Base point is 8 * G
    assert_equal g * 8, b

    # Neutral element is (0, 1)
    neutral = @bjj.infinity
    assert_equal b, b + neutral
    assert_equal neutral, b + (-b)

    # Scalar multiplication by subgroup order l yields neutral element
    order_l = Vellum::Algebra::Fields::BabyJubJubScalar::SUBGROUP_ORDER
    assert (b * order_l).infinity?, "Subgroup order * base point must yield neutral element"
  end
end
