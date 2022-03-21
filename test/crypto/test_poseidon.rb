# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/poseidon/sponge"

class TestPoseidon < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
  end

  def test_sbox_power_of_five
    elem = @field.element(7)
    expected = elem**5
    actual = Vellum::Crypto::Poseidon::SBox.apply(elem)
    assert_equal expected, actual
  end

  def test_deterministic_sponge_hash
    inputs = [@field.element(1), @field.element(2)]
    h1 = Vellum::Crypto::Poseidon.hash(inputs, field: @field)
    h2 = Vellum::Crypto::Poseidon.hash(inputs, field: @field)

    assert_equal h1, h2
    refute_nil h1
    assert h1.is_a?(Vellum::Algebra::FieldElement)
  end

  def test_hash_2_merkle_node
    left = @field.element(42)
    right = @field.element(99)

    node_hash = Vellum::Crypto::Poseidon.hash_2(left, right, field: @field)
    assert node_hash.is_a?(Vellum::Algebra::FieldElement)

    # Different inputs produce different outputs (avalanche)
    node_hash_diff = Vellum::Crypto::Poseidon.hash_2(left, @field.element(100), field: @field)
    refute_equal node_hash, node_hash_diff
  end

  def test_multi_element_absorption
    sponge = Vellum::Crypto::Poseidon::Sponge.new(@field, 2, 1)
    elements = [10, 20, 30, 40, 50].map { |x| @field.element(x) }

    sponge.absorb(elements)
    squeezed = sponge.squeeze(2)

    assert_equal 2, squeezed.length
    refute_equal squeezed[0], squeezed[1]
  end

  def test_zero_elements_hash
    zero = @field.zero
    h = Vellum::Crypto::Poseidon.hash([zero], field: @field)
    refute_equal zero, h
  end
end
