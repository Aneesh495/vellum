# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/circuit/plonkish/table"
require "vellum/circuit/plonkish/gate"
require "vellum/circuit/plonkish/copy_constraints"
require "vellum/crypto/kzg"
require "vellum/prover/plonk"
require "vellum/verifier/plonk"
require "vellum/algebra/pairing/bn254_pairing"

class TestPlonk < Minitest::Test
  def setup
    @engine = Vellum::Algebra::Pairing::BN254Pairing.instance
    @field = @engine.fr

    # 4-row execution table
    @table = Vellum::Circuit::Plonkish::Table.new(@field, 4)
    gate_add = Vellum::Circuit::Plonkish::Gate.addition(@field)
    gate_mul = Vellum::Circuit::Plonkish::Gate.multiplication(@field)

    # Row 0: 2 + 3 = 5 (add)
    @table.add_row(gate_add, 2, 3, 5)
    # Row 1: 5 * 4 = 20 (mul)
    @table.add_row(gate_mul, 5, 4, 20)
    # Row 2: 20 + 7 = 27 (add)
    @table.add_row(gate_add, 20, 7, 27)

    @table.finalize!

    # Copy constraints:
    # row 0 wire c (5) == row 1 wire a (5)
    # row 1 wire c (20) == row 2 wire a (20)
    @copy = Vellum::Circuit::Plonkish::CopyConstraints.new(@table.domain)
    @copy.build_permutation_polynomials([
      [[0, 2], [1, 0]],
      [[1, 2], [2, 0]]
    ])

    @srs = Vellum::Crypto::KZG.setup(@table.domain.size * 4, @engine, 11)
  end

  def test_plonk_prove_and_verify
    proof = Vellum::Prover::Plonk.prove(@table, @copy, @srs)
    refute_nil proof
    refute proof.a_comm.infinity?
    refute proof.z_comm.infinity?

    valid = Vellum::Verifier::Plonk.verify(proof, @srs, @table.domain)
    assert valid, "Valid Plonk proof must be accepted by pairing verifier"
  end

  def test_tampered_plonk_proof_rejected
    proof = Vellum::Prover::Plonk.prove(@table, @copy, @srs)

    # Tamper with evaluation a(zeta)
    tampered_proof = Vellum::Prover::Plonk::Proof.new(
      a_comm: proof.a_comm,
      b_comm: proof.b_comm,
      c_comm: proof.c_comm,
      z_comm: proof.z_comm,
      t_lo_comm: proof.t_lo_comm,
      t_mid_comm: proof.t_mid_comm,
      t_hi_comm: proof.t_hi_comm,
      a_eval: proof.a_eval + @field.one,
      b_eval: proof.b_eval,
      c_eval: proof.c_eval,
      s1_eval: proof.s1_eval,
      s2_eval: proof.s2_eval,
      z_omega_eval: proof.z_omega_eval,
      w_zeta: proof.w_zeta,
      w_zeta_omega: proof.w_zeta_omega
    )

    valid = Vellum::Verifier::Plonk.verify(tampered_proof, @srs, @table.domain)
    refute valid, "Plonk proof with falsified evaluation must fail verification"
  end
end
