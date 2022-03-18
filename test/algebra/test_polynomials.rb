# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/fields/bn254_scalar"
require "vellum/algebra/polynomial"

class TestPolynomials < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
  end

  def test_polynomial_arithmetic
    # p1(X) = 2X^2 + 3X + 1
    p1 = Vellum::Algebra::Polynomial.new(@field, [1, 3, 2])
    # p2(X) = X + 4
    p2 = Vellum::Algebra::Polynomial.new(@field, [4, 1])

    # Addition: 2X^2 + 4X + 5
    sum = p1 + p2
    assert_equal [5, 4, 2].map { |c| @field.element(c) }, sum.coeffs
    assert_equal 2, sum.degree

    # Subtraction: 2X^2 + 2X - 3
    diff = p1 - p2
    assert_equal [-3, 2, 2].map { |c| @field.element(c) }, diff.coeffs

    # Multiplication: (2X^2 + 3X + 1)(X + 4) = 2X^3 + 11X^2 + 13X + 4
    prod = p1 * p2
    expected_coeffs = [4, 13, 11, 2].map { |c| @field.element(c) }
    assert_equal expected_coeffs, prod.coeffs
    assert_equal 3, prod.degree
  end

  def test_polynomial_evaluation
    # P(X) = 3X^2 + 2X + 5
    p = Vellum::Algebra::Polynomial.new(@field, [5, 2, 3])

    # P(0) = 5
    assert_equal @field.element(5), p.evaluate(@field.zero)
    # P(1) = 10
    assert_equal @field.element(10), p.evaluate(@field.one)
    # P(3) = 3(9) + 2(3) + 5 = 27 + 6 + 5 = 38
    assert_equal @field.element(38), p.evaluate(@field.element(3))
  end

  def test_polynomial_division_with_remainder
    # Dividend: A(X) = X^3 - 2X^2 - 4
    a = Vellum::Algebra::Polynomial.new(@field, [-4, 0, -2, 1])
    # Divisor: B(X) = X - 3
    b = Vellum::Algebra::Polynomial.new(@field, [-3, 1])

    quot, rem = a.divmod(b)

    # Invariant: A(X) == quot(X) * B(X) + rem(X)
    reconstructed = (quot * b) + rem
    assert_equal a.coeffs, reconstructed.coeffs
    assert rem.degree < b.degree, "Remainder degree must be strictly less than divisor degree"

    # Evaluation check: A(3) == rem(3)
    assert_equal a.evaluate(@field.element(3)), rem.evaluate(@field.element(3))
  end

  def test_lagrange_interpolation
    # Points: (1, 3), (2, 7), (3, 13)
    # Formula: P(X) = X^2 + X + 1
    # P(1) = 3, P(2) = 7, P(3) = 13
    points = [
      [@field.element(1), @field.element(3)],
      [@field.element(2), @field.element(7)],
      [@field.element(3), @field.element(13)]
    ]

    poly = Vellum::Algebra::Polynomial.interpolate(points)
    assert_equal [1, 1, 1].map { |c| @field.element(c) }, poly.coeffs
    assert_equal 2, poly.degree

    points.each do |x, y|
      assert_equal y, poly.evaluate(x)
    end
  end
end
