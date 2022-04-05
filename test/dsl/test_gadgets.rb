# frozen_string_literal: true

require_relative "../test_helper"
require "vellum"
require "vellum/dsl/gadgets/comparator"
require "vellum/dsl/gadgets/multiplexer"
require "vellum/dsl/gadgets/range"

class TestGadgets < Minitest::Test
  def test_is_zero_gadget
    circuit = Vellum.circuit do
      x = private_input(:x)
      out = public_input(:out)

      is_zero_sig = Vellum::DSL::Gadgets::ComparatorGadget.is_zero(self, x)
      assert_equal(is_zero_sig, out, "is_zero_match")
    end

    pk, vk = circuit.setup

    # Case 1: x = 0 => out = 1
    proof_zero = circuit.prove(pk, { x: 0, out: 1 })
    assert circuit.verify(vk, [1], proof_zero)

    # Case 2: x = 42 => out = 0
    proof_nonzero = circuit.prove(pk, { x: 42, out: 0 })
    assert circuit.verify(vk, [0], proof_nonzero)
  end

  def test_multiplexer_mux2
    circuit = Vellum.circuit do
      cond = private_input(:cond)
      val0 = private_input(:val0)
      val1 = private_input(:val1)
      out = public_input(:out)

      res = Vellum::DSL::Gadgets::MultiplexerGadget.mux2(self, cond, val0, val1)
      assert_equal(res, out, "mux_out")
    end

    pk, vk = circuit.setup

    # cond = 0 => selects val0 (100)
    p0 = circuit.prove(pk, { cond: 0, val0: 100, val1: 200, out: 100 })
    assert circuit.verify(vk, [100], p0)

    # cond = 1 => selects val1 (200)
    p1 = circuit.prove(pk, { cond: 1, val0: 100, val1: 200, out: 200 })
    assert circuit.verify(vk, [200], p1)
  end

  def test_bounded_range_enforcement
    circuit = Vellum.circuit do
      x = private_input(:x)
      out = public_input(:out)

      # Enforce x fits in 8 bits (0..255)
      assert_range(x, 8)
      assert_equal(x, out, "range_out")
    end

    pk, vk = circuit.setup

    # Within range: 250
    p_ok = circuit.prove(pk, { x: 250, out: 250 })
    assert circuit.verify(vk, [250], p_ok)

    # Out of range: 300 (cannot decompose into 8 bits)
    assert_raises(Vellum::ConstraintError) do
      circuit.prove(pk, { x: 300, out: 300 })
    end
  end
end
