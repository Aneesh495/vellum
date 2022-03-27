# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/babyjubjub_eddsa"

class TestBabyJubJubEdDSA < Minitest::Test
  def setup
    @curve = Vellum::Crypto::BabyJubJubEdDSA.curve
    @sk = 12345678901234567890
    @pk = Vellum::Crypto::BabyJubJubEdDSA.public_key(@sk)
    @msg = 424242
  end

  def test_public_key_derivation
    assert @curve.on_curve?(@pk), "Derived public key must lie on BabyJubJub curve"
  end

  def test_sign_and_verify
    sig = Vellum::Crypto::BabyJubJubEdDSA.sign(@sk, @msg)
    refute_nil sig
    assert @curve.on_curve?(sig.r_point)

    valid = Vellum::Crypto::BabyJubJubEdDSA.verify(@pk, @msg, sig)
    assert valid, "Valid BabyJubJub EdDSA signature must pass verification"
  end

  def test_tampered_message_rejected
    sig = Vellum::Crypto::BabyJubJubEdDSA.sign(@sk, @msg)
    tampered_msg = @msg + 1

    valid = Vellum::Crypto::BabyJubJubEdDSA.verify(@pk, tampered_msg, sig)
    refute valid, "Signature must fail verification on tampered message"
  end

  def test_tampered_signature_rejected
    sig = Vellum::Crypto::BabyJubJubEdDSA.sign(@sk, @msg)
    sub_order = @curve.subgroup_order

    # Corrupt scalar s
    corrupted_s = (sig.s_scalar + 1) % sub_order
    corrupted_sig = Vellum::Crypto::BabyJubJubEdDSA::Signature.new(sig.r_point, corrupted_s)

    valid = Vellum::Crypto::BabyJubJubEdDSA.verify(@pk, @msg, corrupted_sig)
    refute valid, "Signature with tampered scalar must be rejected"
  end

  def test_wrong_public_key_rejected
    sig = Vellum::Crypto::BabyJubJubEdDSA.sign(@sk, @msg)
    wrong_sk = 987654321
    wrong_pk = Vellum::Crypto::BabyJubJubEdDSA.public_key(wrong_sk)

    valid = Vellum::Crypto::BabyJubJubEdDSA.verify(wrong_pk, @msg, sig)
    refute valid, "Signature must be rejected when verified against wrong public key"
  end
end
