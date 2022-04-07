# frozen_string_literal: true

require_relative "../test_helper"
require "vellum"
require "vellum/codegen/solidity_groth16"
require "vellum/codegen/solidity_plonk"
require "vellum/crypto/kzg"

class TestSolidityVerifier < Minitest::Test
  def setup
    @circuit = Vellum.circuit do
      x = private_input(:x)
      out = public_input(:out)
      assert_equal(x * x, out, "square")
    end
    _, @vk = @circuit.setup

    engine = Vellum::Algebra::Pairing::BN254Pairing.instance
    @srs = Vellum::Crypto::KZG.setup(8, engine, 5)
  end

  def test_groth16_solidity_generation
    code = Vellum::Codegen::SolidityGroth16.generate(@vk, "CubicVerifier")
    refute_nil code
    assert_includes code, "contract CubicVerifier"
    assert_includes code, "function verifyProof"
    assert_includes code, "Pairing.G1Point("
    assert_includes code, "Pairing.G2Point("
    assert_includes code, "vk.ic[0]"
    refute_includes code, "\u2014", "Generated Solidity must not contain em dashes"
  end

  def test_plonk_solidity_generation
    code = Vellum::Codegen::SolidityPlonk.generate(@srs, "PlonkVerifier")
    refute_nil code
    assert_includes code, "contract PlonkVerifier"
    assert_includes code, "struct Proof"
    assert_includes code, "G1_TAU_X"
    assert_includes code, "G2_TAU_X0"
    refute_includes code, "\u2014", "Generated Solidity must not contain em dashes"
  end
end
