# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/plonkish/gate"
require "vellum/circuit/plonkish/table"
require "vellum/circuit/plonkish/copy_constraints"
require "vellum/circuit/air/trace"
require "vellum/circuit/air/boundary"
require "vellum/circuit/air/composition"
require "vellum/algebra/fields/bn254_scalar"
require "vellum/algebra/fields/goldilocks"

class TestPlonkishAndAIR < Minitest::Test
  def setup
    @bn_field = Vellum::Algebra::Fields::BN254Scalar.instance
    @goldilocks = Vellum::Algebra::Fields::Goldilocks.instance
  end

  def test_plonkish_canonical_gates
    # Add: a + b - c = 0
    add_gate = Vellum::Circuit::Plonkish::Gate.addition(@bn_field)
    assert add_gate.satisfied?(@bn_field.element(3), @bn_field.element(4), @bn_field.element(7))
    refute add_gate.satisfied?(@bn_field.element(3), @bn_field.element(4), @bn_field.element(8))

    # Mul: a * b - c = 0
    mul_gate = Vellum::Circuit::Plonkish::Gate.multiplication(@bn_field)
    assert mul_gate.satisfied?(@bn_field.element(5), @bn_field.element(6), @bn_field.element(30))

    # Boolean: a * a - a = 0
    bool_gate = Vellum::Circuit::Plonkish::Gate.boolean(@bn_field)
    assert bool_gate.satisfied?(@bn_field.zero, @bn_field.zero, @bn_field.zero)
    assert bool_gate.satisfied?(@bn_field.one, @bn_field.one, @bn_field.zero)
    refute bool_gate.satisfied?(@bn_field.element(2), @bn_field.element(2), @bn_field.zero)
  end

  def test_plonkish_table_and_permutation_accumulator
    table = Vellum::Circuit::Plonkish::Table.new(@bn_field, 4)
    gate = Vellum::Circuit::Plonkish::Gate.addition(@bn_field)

    # 1 + 2 = 3
    table.add_row(gate, 1, 2, 3)
    # 3 + 4 = 7
    table.add_row(gate, 3, 4, 7)
    table.finalize!

    assert table.satisfied?
    assert_equal 4, table.domain.size

    # Copy constraint: row 0 col 2 (3) == row 1 col 0 (3)
    copy = Vellum::Circuit::Plonkish::CopyConstraints.new(table.domain)
    copy.build_permutation_polynomials([[[0, 2], [1, 0]]])

    beta = @bn_field.element(17)
    gamma = @bn_field.element(23)
    poly_z = copy.compute_accumulator_polynomial(table, beta, gamma)

    refute_nil poly_z
    # Z(omega^0) == 1
    assert_equal @bn_field.one, poly_z.evaluate(table.domain.elements.first)
  end

  def test_stark_air_trace_and_lde
    trace = Vellum::Circuit::AIR::Trace.new(@goldilocks, 2, 4)
    4.times do |step|
      trace.set(step, 0, (step + 1) * 10)
      trace.set(step, 1, step * step)
    end

    assert_equal 4, trace.num_steps
    assert_equal @goldilocks.element(30), trace.get(2, 0)

    # Low-degree extension with 4x blowup
    lde = trace.low_degree_extension(4, 3)
    assert_equal 16, lde[:domain].size
    assert_equal 2, lde[:columns].length
    assert_equal 16, lde[:columns].first.length
  end

  def test_stark_air_boundaries_and_composition
    trace = Vellum::Circuit::AIR::Trace.new(@goldilocks, 1, 4)
    trace.set(0, 0, 42)
    trace.set(1, 0, 50)
    trace.set(2, 0, 60)
    trace.set(3, 0, 70)

    b0 = Vellum::Circuit::AIR::Boundary.new(@goldilocks, trace.domain, 0, 0, 42)
    b_term = Vellum::Circuit::AIR::Boundary.new(@goldilocks, trace.domain, 3, 0, 70)

    assert b0.satisfied?(trace)
    assert b_term.satisfied?(trace)

    comp = Vellum::Circuit::AIR::Composition.new(trace, [], [b0, b_term])
    alpha = @goldilocks.element(13)
    beta = @goldilocks.element(29)

    comp_poly = comp.build_composition_polynomial(alpha, beta)
    refute_nil comp_poly
    refute comp_poly.zero?
  end
end
