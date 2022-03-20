# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/blake2s"

class TestBlake2s < Minitest::Test
  def test_empty_string_vector
    expected = "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9"
    assert_equal expected, Vellum::Crypto::Blake2s.hexdigest("")
  end

  def test_quick_brown_fox_vector
    expected = "606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812"
    assert_equal expected, Vellum::Crypto::Blake2s.hexdigest("The quick brown fox jumps over the lazy dog")
  end

  def test_multi_block_streaming
    data = "a" * 200
    expected = "2b033f9f5ba9cf20671da79e492f41545e673b562603945ffed09662fd92321a"
    assert_equal expected, Vellum::Crypto::Blake2s.hexdigest(data)

    # Chunked update
    hasher = Vellum::Crypto::Blake2s.new
    hasher.update("a" * 50)
    hasher.update("a" * 150)
    assert_equal expected, hasher.hexdigest
  end

  def test_keyed_hashing
    key = "secret_key_1234"
    msg = "hello world"
    expected = "21ac0d1c7a5697d4112c34e90b56010b8ce4d19c22ab40821d5e7d1b43ad17f4"
    actual = Vellum::Crypto::Blake2s.new(32, key).update(msg).hexdigest
    assert_equal expected, actual
  end

  def test_custom_digest_length
    out16 = Vellum::Crypto::Blake2s.new(16).update("abc").digest
    assert_equal 16, out16.bytesize

    out32 = Vellum::Crypto::Blake2s.new(32).update("abc").digest
    assert_equal 32, out32.bytesize
  end
end
