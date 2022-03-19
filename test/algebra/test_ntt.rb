# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/algebra/fields/bn254_scalar"
require "vellum/algebra/evaluation_domain"
require "vellum/algebra/ntt"
require "vellum/algebra/polynomial"

class TestNTT < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @domain = Vellum::Algebra::EvaluationDomain.new(@field, 8)
  end

  def test_evaluation_domain_properties
    assert_equal 8, @domain.size
    omega = @domain.group_gen

    # omega^8 == 1
    assert_equal @field.one, omega**8
    # omega^4 == -1
    assert_equal -@field.one, omega**4

    # Elements in domain are distinct powers of omega
    elements = @domain.elements
    assert_equal 8, elements.uniq.length

    # Vanishing polynomial: X^8 - 1
    zh = @domain.vanishing_polynomial
    elements.each do |w|
      assert_equal @field.zero, zh.evaluate(w), "Vanishing polynomial must vanish at all roots of unity"
    end

    # Outside domain, e.g. at 2, Z_H(2) == 2^8 - 1 == 255
    assert_equal @field.element(255), zh.evaluate(@field.element(2))
  end

  def test_forward_and_inverse_ntt_roundtrip
    # Random-like coefficients
    coeffs = [3, 14, 15, 92, 65, 35, 89, 79].map { |x| @field.element(x) }

    # Forward NTT: evaluations at omega^0 .. omega^7
    evals = Vellum::Algebra::NTT.forward(coeffs, @domain)
    assert_equal 8, evals.length

    # Verify each evaluation directly via polynomial evaluation
    poly = Vellum::Algebra::Polynomial.new(@field, coeffs)
    @domain.elements.each_with_index do |w, i|
      assert_equal poly.evaluate(w), evals[i], "NTT evaluation at omega^#{i} must match direct evaluation"
    end

    # Inverse NTT: recover coefficients
    recovered = Vellum::Algebra::NTT.inverse(evals, @domain)
    assert_equal coeffs, recovered, "Inverse NTT must perfectly recover original coefficients"
  end

  def test_coset_ntt_roundtrip
    coeffs = [7, 11, 13, 17, 19, 23, 29, 31].map { |x| @field.element(x) }
    shift = @field.element(5)

    # Coset forward
    coset_evals = Vellum::Algebra::NTT.coset_forward(coeffs, @domain, shift)
    assert_equal 8, coset_evals.length

    # Verify coset evaluations: poly.evaluate(shift * omega^i)
    poly = Vellum::Algebra::Polynomial.new(@field, coeffs)
    @domain.elements.each_with_index do |w, i|
      assert_equal poly.evaluate(shift * w), coset_evals[i]
    end

    # Coset inverse
    recovered = Vellum::Algebra::NTT.coset_inverse(coset_evals, @domain, shift)
    assert_equal coeffs, recovered
  end

  def test_fast_polynomial_multiplication_via_ntt
    p1 = Vellum::Algebra::Polynomial.new(@field, [1, 2, 3])
    p2 = Vellum::Algebra::Polynomial.new(@field, [4, 5, 6])

    # Standard Karatsuba / schoolbook multiplication
    expected_prod = p1 * p2

    # Fast NTT multiplication
    fast_prod = Vellum::Algebra::NTT.multiply_polynomials(p1, p2)

    assert_equal expected_prod.coeffs, fast_prod.coeffs
  end
end
