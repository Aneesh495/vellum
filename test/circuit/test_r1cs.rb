# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/r1cs"
require "vellum/algebra/fields/bn254_scalar"

class TestR1CS < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @r1cs = Vellum::Circuit::R1CS.new(@field)

    @allocator = @r1cs.wire_allocator
    @one = @allocator.one_variable
    @x = @allocator.allocate_private("x")
    @out = @allocator.allocate_public("out")
    @x2 = @allocator.allocate_internal("x2")

    # Constraint 1: x * x = x2
    @r1cs.add_constraint(@x, @x, @x2, "x_sq")

    # Constraint 2: (x2 + x) * ONE = (out - 5*ONE) => x^2 + x + 5 = out
    lc_lhs = Vellum::Circuit::LinearCombination.from_variable(@x2, @field) +
             Vellum::Circuit::LinearCombination.from_variable(@x, @field)
    lc_rhs = Vellum::Circuit::LinearCombination.from_variable(@out, @field) -
             Vellum::Circuit::LinearCombination.constant(@field, 5, @one)
    @r1cs.add_constraint(lc_lhs, @one, lc_rhs, "sum_rel")

    @allocator.reindex!
  end

  def test_r1cs_dimensions
    assert_equal 2, @r1cs.num_constraints
    assert_equal 4, @r1cs.num_variables
    assert_equal 1, @r1cs.num_public
    assert_equal 2, @r1cs.num_private
  end

  def test_build_sparse_matrices
    mat_a, mat_b, mat_c = @r1cs.build_matrices
    assert_equal 2, mat_a.num_rows
    assert_equal 4, mat_a.num_cols

    # In row 0: A has 1 at x, B has 1 at x, C has 1 at x2
    assert_equal @field.one, mat_a.get(0, @x.id)
    assert_equal @field.one, mat_b.get(0, @x.id)
    assert_equal @field.one, mat_c.get(0, @x2.id)
  end

  def test_satisfaction_with_valid_witness
    # Solution: x = 3 => x^2 = 9 => x^2 + x + 5 = 17 => out = 17
    # Vector: [ONE, out, x, x2]
    witness = {
      @one => 1,
      @out => 17,
      @x => 3,
      @x2 => 9
    }

    assert @r1cs.satisfied?(witness), "Valid witness must satisfy R1CS"

    audit_res = @r1cs.audit(witness)
    assert audit_res[:satisfied]
    assert_empty audit_res[:violations]
  end

  def test_unsatisfied_witness_rejection
    # Corrupt out: out = 18 instead of 17
    bad_witness = {
      @one => 1,
      @out => 18,
      @x => 3,
      @x2 => 9
    }

    refute @r1cs.satisfied?(bad_witness), "Unsatisfied witness must be rejected"

    audit_res = @r1cs.audit(bad_witness)
    refute audit_res[:satisfied]
    assert_equal 1, audit_res[:violations].length
    assert_equal "sum_rel", audit_res[:violations].first[:label]
  end
end
