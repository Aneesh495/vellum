# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/variable"
require "vellum/circuit/wire_allocator"
require "vellum/circuit/linear_combination"
require "vellum/algebra/fields/bn254_scalar"

class TestVariableAndLC < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @allocator = Vellum::Circuit::WireAllocator.new
    @one = @allocator.one_variable
  end

  def test_wire_allocator_canonical_partitioning
    one_var = @allocator.one_variable
    assert_equal 0, one_var.id
    assert one_var.constant?

    pub1 = @allocator.allocate_public("pub1")
    pub2 = @allocator.allocate_public("pub2")

    priv1 = @allocator.allocate_private("priv1")
    priv2 = @allocator.allocate_private("priv2")

    @allocator.reindex!

    assert_equal 0, one_var.id
    assert_equal 1, pub1.id
    assert_equal 2, pub2.id
    assert_equal 3, priv1.id
    assert_equal 4, priv2.id

    assert_equal 2, @allocator.num_public
    assert_equal 2, @allocator.num_private
    assert_equal 5, @allocator.num_variables
  end

  def test_linear_combination_arithmetic
    v1 = Vellum::Circuit::Variable.new(1, "x", :public_input)
    v2 = Vellum::Circuit::Variable.new(2, "y", :private_witness)

    # lc1 = 3*x + 5*ONE
    lc1 = Vellum::Circuit::LinearCombination.from_variable(v1, @field, 3) +
          Vellum::Circuit::LinearCombination.constant(@field, 5, @one)

    # lc2 = 2*y - 4*ONE
    lc2 = Vellum::Circuit::LinearCombination.from_variable(v2, @field, 2) -
          Vellum::Circuit::LinearCombination.constant(@field, 4, @one)

    # lc_sum = lc1 + lc2 = 3*x + 2*y + 1*ONE
    lc_sum = lc1 + lc2
    assert_equal @field.element(3), lc_sum.terms[v1]
    assert_equal @field.element(2), lc_sum.terms[v2]
    assert_equal @field.element(1), lc_sum.terms[@one]

    # Scalar multiplication: 2 * lc_sum = 6*x + 4*y + 2*ONE
    lc_scaled = lc_sum * 2
    assert_equal @field.element(6), lc_scaled.terms[v1]
    assert_equal @field.element(4), lc_scaled.terms[v2]
    assert_equal @field.element(2), lc_scaled.terms[@one]
  end

  def test_linear_combination_evaluation
    v1 = Vellum::Circuit::Variable.new(1, "x", :public_input)
    v2 = Vellum::Circuit::Variable.new(2, "y", :private_witness)

    lc = Vellum::Circuit::LinearCombination.new(@field, {
      v1 => 4,
      v2 => 7,
      @one => 11
    })

    # Witness assignment: x = 2, y = 3, ONE = 1
    # Value: 4(2) + 7(3) + 11(1) = 8 + 21 + 11 = 40
    assignment = {
      0 => @field.one,
      1 => @field.element(2),
      2 => @field.element(3)
    }

    eval_val = lc.evaluate(assignment)
    assert_equal @field.element(40), eval_val
  end
end
