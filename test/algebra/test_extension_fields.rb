# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/fields/bn254_base"
require "vellum/algebra/extensions/fp2"
require "vellum/algebra/extensions/fp6"
require "vellum/algebra/extensions/fp12"

class TestExtensionFields < Minitest::Test
  def setup
    @fp = Vellum::Algebra::Fields::BN254Base.instance
    @fp2 = Vellum::Algebra::Extensions::Fp2.new(@fp, -1)
    @fp6 = Vellum::Algebra::Extensions::Fp6.new(@fp2, :bn254)
    @fp12 = Vellum::Algebra::Extensions::Fp12.new(@fp6)
  end

  def test_fp2_basic_arithmetic_and_inversion
    a = @fp2.element([3, 7])
    b = @fp2.element([5, 11])

    # Addition
    sum = a + b
    assert_equal @fp2.element([8, 18]), sum

    # Subtraction
    diff = a - b
    assert_equal a, diff + b

    # Multiplicative inverse: a * a^-1 == 1
    inv_a = a.inv
    prod = a * inv_a
    assert_equal @fp2.one, prod
  end

  def test_fp2_frobenius_map
    # In Fp2 with non-residue -1 (u^2 = -1):
    # Frobenius automorphism (a + b*u)^p == a - b*u
    a = @fp2.element([17, 43])
    frob = a.frobenius
    expected = @fp2.element([17, -43])
    assert_equal expected, frob
  end

  def test_fp6_arithmetic_and_inversion
    c0 = @fp2.element([2, 3])
    c1 = @fp2.element([5, 7])
    c2 = @fp2.element([11, 13])
    x = @fp6.element([c0, c1, c2])

    # Inversion
    inv_x = x.inv
    prod = x * inv_x
    assert_equal @fp6.one, prod

    # Distributive property
    y = @fp6.element([@fp2.element([1, 1]), @fp2.element([2, 2]), @fp2.element([3, 3])])
    z = @fp6.element([@fp2.element([4, 1]), @fp2.element([0, 2]), @fp2.element([1, 5])])

    assert_equal (x + y) * z, (x * z) + (y * z)
  end

  def test_fp12_arithmetic_and_inversion
    c0 = @fp2.element([1, 2])
    c1 = @fp2.element([3, 4])
    c2 = @fp2.element([5, 6])
    f0 = @fp6.element([c0, c1, c2])

    d0 = @fp2.element([7, 8])
    d1 = @fp2.element([9, 10])
    d2 = @fp2.element([11, 12])
    f1 = @fp6.element([d0, d1, d2])

    w = @fp12.element([f0, f1])

    # Inversion: w * w^-1 == 1 in Fp12
    inv_w = w.inv
    assert_equal @fp12.one, w * inv_w

    # Conjugate
    conj = w.conjugate
    assert_equal @fp12.element([f0, -f1]), conj
  end

  def test_fp12_exponentiation
    c0 = @fp2.element([1, 1])
    c1 = @fp2.element([0, 2])
    c2 = @fp2.element([3, 0])
    f0 = @fp6.element([c0, c1, c2])
    f1 = @fp6.zero
    elem = @fp12.element([f0, f1])

    sq = elem * elem
    pow2 = elem**2
    assert_equal sq, pow2
  end
end
