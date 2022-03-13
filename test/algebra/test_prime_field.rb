# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/prime_field"
require "vellum/algebra/fields/bn254_base"
require "vellum/algebra/fields/bn254_scalar"
require "vellum/algebra/fields/goldilocks"
require "vellum/algebra/fields/bls12_381_base"
require "vellum/algebra/fields/bls12_381_scalar"
require "vellum/algebra/fields/babyjubjub_base"
require "vellum/algebra/fields/babyjubjub_scalar"

class TestPrimeField < Minitest::Test
  def setup
    @fp = Vellum::Algebra::Fields::BN254Base.instance
    @fr = Vellum::Algebra::Fields::BN254Scalar.instance
    @goldilocks = Vellum::Algebra::Fields::Goldilocks.instance
  end

  def test_additive_identity_and_inverse
    a = @fp.element(42)
    zero = @fp.zero

    assert_equal a, a + zero
    assert_equal a, zero + a
    assert_equal zero, a + (-a)
    assert_equal zero, a - a
  end

  def test_multiplicative_identity_and_inverse
    a = @fp.element(1337)
    one = @fp.one

    assert_equal a, a * one
    assert_equal a, one * a
    assert_equal one, a * a.inv
    assert_equal one, a / a
  end

  def test_distributive_law
    a = @fp.element(17)
    b = @fp.element(23)
    c = @fp.element(31)

    lhs = (a + b) * c
    rhs = (a * c) + (b * c)
    assert_equal lhs, rhs
  end

  def test_exponentiation_and_fermats_little_theorem
    a = @fp.element(7)
    assert_equal @fp.element(343), a**3

    # Fermat's Little Theorem: a^(p-1) == 1 mod p
    p_minus_1 = @fp.modulus - 1
    assert_equal @fp.one, a**p_minus_1
  end

  def test_tonelli_shanks_square_root
    # Take a known square: 19^2
    a = @fp.element(19)
    sq = a * a
    root = sq.sqrt

    refute_nil root
    assert_equal sq, root * root

    # Non-quadratic residue returns nil or raises
    # For BN254 base field, 5 is a non-residue or has Legendre symbol -1
    (2..50).each do |cand|
      elem = @fp.element(cand)
      unless elem.quadratic_residue?
        assert_nil elem.sqrt
        break
      end
    end
  end

  def test_goldilocks_fast_reduction
    # Goldilocks modulus p = 2^64 - 2^32 + 1
    p = Vellum::Algebra::Fields::Goldilocks::MODULUS
    x = (1 << 64) + 100
    expected = (x % p)
    actual = @goldilocks.fast_reduce(x)
    assert_equal expected, actual

    g_elem = @goldilocks.element(123456789)
    assert_equal g_elem * g_elem.inv, @goldilocks.one
  end

  def test_various_field_moduli_consistency
    fields = [
      Vellum::Algebra::Fields::BN254Base.instance,
      Vellum::Algebra::Fields::BN254Scalar.instance,
      Vellum::Algebra::Fields::BLS12381Base.instance,
      Vellum::Algebra::Fields::BLS12381Scalar.instance,
      Vellum::Algebra::Fields::BabyJubJubBase.instance,
      Vellum::Algebra::Fields::BabyJubJubScalar.instance
    ]

    fields.each do |f|
      x = f.element(101)
      y = f.element(202)
      sum = x + y
      prod = x * y

      assert_equal f.element(303), sum
      assert_equal f.one, x * x.inv
      assert_equal f.zero, sum - sum
    end
  end
end
