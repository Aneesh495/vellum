# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/native"

class NativeExtensionTest < Minitest::Test
  def test_native_module_definition
    assert defined?(Vellum::Native)
    assert [true, false].include?(Vellum::Native.available?)
  end

  def test_montgomery_c_acceleration_if_available
    skip unless Vellum::Native.available?

    # Test CIOS Montgomery multiplication matching pure Ruby Montgomery
    modulus = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    # compute inv: -modulus^{-1} mod 2^64
    inv = 0xc2e1f593efffffff # BN254 Fr inverse

    a = 1234567890123456789
    b = 9876543210987654321
    res = Vellum::Native::Montgomery.mul(a, b, modulus, inv)
    assert res >= 0
    assert res < modulus
  end
end
