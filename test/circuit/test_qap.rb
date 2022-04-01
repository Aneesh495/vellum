# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/r1cs"
require "vellum/circuit/qap"
require "vellum/algebra/fields/bn254_scalar"

class TestQAP < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @r1cs = Vellum::Circuit::R1CS.new(@field)
    @alloc = @r1cs.wire_allocator

    @one = @alloc.one_variable
    @x = @alloc.allocate_private("x")
    @out = @alloc.allocate_public("out")
    @x2 = @alloc.allocate_internal("x2")

    # x * x = x2
    @r1cs.add_constraint(@x, @x, @x2)
    # (x2 + x) * ONE = out - 5*ONE => x^2 + x + 5 = out
    lc1 = Vellum::Circuit::LinearCombination.from_variable(@x2, @field) +
          Vellum::Circuit::LinearCombination.from_variable(@x, @field)
    lc2 = Vellum::Circuit::LinearCombination.from_variable(@out, @field) -
          Vellum::Circuit::LinearCombination.constant(@field, 5, @one)
    @r1cs.add_constraint(lc1, @one, lc2)

    @alloc.reindex!
    @qap = Vellum::Circuit::QAP.new(@r1cs)
  end

  def test_qap_divisibility_with_valid_witness
    # x = 3 => x^2 = 9 => out = 17
    # Canonical order: [ONE, out, x, x2]
    w_vec = [1, 17, 3, 9]

    res = @qap.witness_map(w_vec)
    refute_nil res[:h]
    refute_nil res[:a]
    refute_nil res[:b]
    refute_nil res[:c]

    # Check identity: A(X)*B(X) - C(X) == H(X)*Z_H(X)
    zh = @qap.domain.vanishing_polynomial
    expected_p = res[:h] * zh
    actual_p = (res[:a] * res[:b]) - res[:c]

    assert_equal expected_p.coeffs, actual_p.coeffs

    # Evaluation check at arbitrary test point tau = 42
    tau = @field.element(42)
    a_val = res[:a].evaluate(tau)
    b_val = res[:b].evaluate(tau)
    c_val = res[:c].evaluate(tau)
    h_val = res[:h].evaluate(tau)
    zh_val = zh.evaluate(tau)

    assert_equal (a_val * b_val) - c_val, h_val * zh_val
  end

  def test_qap_witness_map_fails_on_invalid_witness
    # Invalid out = 18 instead of 17
    bad_vec = [1, 18, 3, 9]

    assert_raises(Vellum::ConstraintError) do
      @qap.witness_map(bad_vec)
    end
  end
end
