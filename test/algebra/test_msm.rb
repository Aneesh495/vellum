# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/curves/bn254_g1"
require "vellum/algebra/msm"

class TestMSM < Minitest::Test
  def setup
    @curve = Vellum::Algebra::Curves::BN254G1.instance
    @g = @curve.generator
    @field = @curve.scalar_field
  end

  def test_empty_and_single_element_msm
    # Empty
    assert_nil Vellum::Algebra::MSM.multi_scalar_mul([], [])

    # Single element
    p = @g * 5
    s = @field.element(7)
    expected = p * 7
    actual = Vellum::Algebra::MSM.multi_scalar_mul([p], [s])
    assert_equal expected, actual
  end

  def test_naive_msm_correctness
    points = [
      @g,
      @g * 2,
      @g * 3,
      @g * 5
    ]
    scalars = [
      @field.element(3),
      @field.element(4),
      @field.element(2),
      @field.element(1)
    ]

    # Expected: 3*g + 4*(2g) + 2*(3g) + 1*(5g) = (3 + 8 + 6 + 5)*g = 22*g
    expected = @g * 22
    actual = Vellum::Algebra::MSM.naive_msm(points, scalars)
    assert_equal expected, actual
  end

  def test_pippenger_matches_naive_msm
    n = 18
    points = []
    scalars = []

    n.times do |i|
      points << (@g * (i + 1))
      scalars << @field.element((i * 17) + 3)
    end

    naive_res = Vellum::Algebra::MSM.naive_msm(points, scalars)
    pippenger_res = Vellum::Algebra::MSM.pippenger(points, scalars)
    auto_res = Vellum::Algebra::MSM.multi_scalar_mul(points, scalars)

    assert_equal naive_res, pippenger_res
    assert_equal naive_res, auto_res
  end

  def test_zero_scalars_and_infinity_points
    points = [@g, @curve.infinity, @g * 4]
    scalars = [@field.zero, @field.element(10), @field.element(3)]

    # 0*g + 10*inf + 3*(4g) = 12g
    expected = @g * 12
    actual = Vellum::Algebra::MSM.multi_scalar_mul(points, scalars)
    assert_equal expected, actual
  end
end
