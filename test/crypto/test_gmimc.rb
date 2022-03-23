# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/gmimc"

class TestGMiMC < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
  end

  def test_deterministic_hash
    inputs = [@field.element(123), @field.element(456)]
    h1 = Vellum::Crypto::GMiMC.hash(inputs, field: @field)
    h2 = Vellum::Crypto::GMiMC.hash(inputs, field: @field)

    assert_equal h1, h2
    refute_nil h1
    assert h1.is_a?(Vellum::Algebra::FieldElement)
  end

  def test_gmimc_avalanche_effect
    a = @field.element(1)
    b1 = @field.element(2)
    b2 = @field.element(3)

    h1 = Vellum::Crypto::GMiMC.hash([a, b1], field: @field)
    h2 = Vellum::Crypto::GMiMC.hash([a, b2], field: @field)

    refute_equal h1, h2
  end

  def test_feistel_state_permutation
    sponge = Vellum::Crypto::GMiMC.new(@field, 2, 1)
    initial_state = sponge.state.dup
    sponge.permute!

    refute_equal initial_state, sponge.state
    assert_equal 3, sponge.state.length
  end
end
