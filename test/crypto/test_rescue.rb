# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/rescue/sponge"

class TestRescue < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
  end

  def test_forward_and_inverse_power_maps
    sponge = Vellum::Crypto::Rescue::Sponge.new(@field)
    alpha = sponge.alpha
    alpha_inv = sponge.alpha_inv

    # Check (alpha * alpha_inv) == 1 mod (p - 1)
    mod_order = @field.modulus - 1
    assert_equal 1, (alpha * alpha_inv) % mod_order

    # Check roundtrip: (x^alpha)^alpha_inv == x
    x = @field.element(123456789)
    forward = x**alpha
    recovered = forward**alpha_inv
    assert_equal x, recovered
  end

  def test_deterministic_rescue_hash
    inputs = [@field.element(17), @field.element(42)]
    h1 = Vellum::Crypto::Rescue.hash(inputs, field: @field)
    h2 = Vellum::Crypto::Rescue.hash(inputs, field: @field)

    assert_equal h1, h2
    refute_nil h1
  end

  def test_rescue_hash_2_avalanche
    left = @field.element(100)
    right1 = @field.element(200)
    right2 = @field.element(201)

    h1 = Vellum::Crypto::Rescue.hash_2(left, right1, field: @field)
    h2 = Vellum::Crypto::Rescue.hash_2(left, right2, field: @field)

    refute_equal h1, h2
  end
end
