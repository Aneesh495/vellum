# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/r1cs"
require "vellum/circuit/r1cs_optimizer"
require "vellum/algebra/fields/bn254_scalar"

class TestR1CSOptimizer < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @r1cs = Vellum::Circuit::R1CS.new(@field)
    @alloc = @r1cs.wire_allocator

    @x = @alloc.allocate_private("x")
    @y = @alloc.allocate_private("y")
    @out = @alloc.allocate_public("out")

    # Constraint: x * y = out
    @r1cs.add_constraint(@x, @y, @out)
  end

  def test_optimizer_clean_circuit
    optimizer = Vellum::Circuit::R1CSOptimizer.new(@r1cs)
    stats = optimizer.optimize

    assert_equal 0, stats[:dead_wires_eliminated]
    assert_equal 4, stats[:optimized_variables] # ONE, x, y, out
  end

  def test_dead_wire_detection
    # Allocate dead internal signals that never appear in constraints
    @alloc.allocate_internal("dead1")
    @alloc.allocate_internal("dead2")
    @alloc.allocate_internal("dead3")

    optimizer = Vellum::Circuit::R1CSOptimizer.new(@r1cs)
    stats = optimizer.optimize

    assert_equal 7, stats[:original_variables]
    assert_equal 4, stats[:optimized_variables]
    assert_equal 3, stats[:dead_wires_eliminated]
  end

  def test_public_variables_always_preserved
    # Allocate public output that isn't yet constrained
    @alloc.allocate_public("unconstrained_public")

    optimizer = Vellum::Circuit::R1CSOptimizer.new(@r1cs)
    stats = optimizer.optimize

    # Unconstrained public variable must NOT be treated as dead wire
    assert_equal 0, stats[:dead_wires_eliminated]
    assert_equal 5, stats[:optimized_variables]
  end
end
