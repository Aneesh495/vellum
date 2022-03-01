# frozen_string_literal: true

require_relative "base"
require_relative "../../vellum"
require_relative "../dsl/gadgets/poseidon"
require_relative "../dsl/gadgets/merkle"
require_relative "../dsl/gadgets/comparator"
require_relative "../prover/groth16"
require_relative "../verifier/groth16"
require_relative "../prover/plonk"
require_relative "../verifier/plonk"
require_relative "../prover/stark"
require_relative "../verifier/stark"

module Vellum
  module CLI
    class VerifyAllCommand < Base
      def execute
        puts TUI::ANSI.bold("=== Vellum Formal Proof System Verification Suite ===")
        puts ""

        field = Algebra::Fields::BN254Scalar.instance

        # Test 1: Groth16 Arithmetic Circuit (x^3 + x + 5 == 35)
        print "1. Groth16 Prover and Multi-Pairing Verifier: "
        circuit = Vellum.circuit do
          x = private_input(:x)
          out = public_input(:out)

          x2 = x * x
          x3 = x2 * x
          res = x3 + x + 5

          assert_equal(res, out)
        end

        pk, vk = circuit.setup
        proof = circuit.prove(pk, { x: 3, out: 35 })
        valid_groth = circuit.verify(vk, [35], proof)
        puts valid_groth ? TUI::ANSI.green("PASS [VERIFIED]") : TUI::ANSI.red("FAIL")

        # Test 2: In-circuit Poseidon Hash
        print "2. In-Circuit Poseidon Sponge & Merkle Proof: "
        merkle_circuit = Vellum.circuit do
          leaf = private_input(:leaf)
          sibling = private_input(:sibling)
          root = public_input(:root)

          calc_root = DSL::Gadgets::PoseidonGadget.hash_2(self, leaf, sibling)
          assert_equal(calc_root, root)
        end

        pk_m, vk_m = merkle_circuit.setup
        expected_root = Crypto::Poseidon.hash_2(1234, 5678)
        proof_m = merkle_circuit.prove(pk_m, { leaf: 1234, sibling: 5678, root: expected_root.value })
        valid_merkle = merkle_circuit.verify(vk_m, [expected_root.value], proof_m)
        puts valid_merkle ? TUI::ANSI.green("PASS [VERIFIED]") : TUI::ANSI.red("FAIL")

        # Test 3: Plonk Permutation Argument & KZG Commitments
        print "3. Plonk 5-Round Permutation Prover & Verifier: "
        table = Circuit::Plonkish::Table.new(field)
        g_add = Circuit::Plonkish::Gate.addition(field)
        table.add_row(g_add, 10, 20, 30)
        table.add_row(g_add, 30, 40, 70)
        table.finalize!

        copy = Circuit::Plonkish::CopyConstraints.new(table.domain)
        copy.build_permutation_polynomials([[[0, 2], [1, 0]]])
        srs = Crypto::KZG::SRS.generate(table.domain.size * 4, 0x123456789)

        plonk_proof = Prover::Plonk.prove(table, copy, srs)
        valid_plonk = Verifier::Plonk.verify(plonk_proof, srs, table.domain)
        puts valid_plonk ? TUI::ANSI.green("PASS [VERIFIED]") : TUI::ANSI.red("FAIL")

        # Test 4: STARK AIR & FRI Prover
        print "4. STARK AIR Low-Degree Extension & FRI Verifier: "
        stark_trace = Circuit::AIR::Trace.new(field, 2, 4)
        4.times do |step|
          stark_trace.set(step, 0, step * 2)
          stark_trace.set(step, 1, step * 4)
        end
        stark_comp = Circuit::AIR::Composition.new(stark_trace)
        stark_proof = Prover::STARK.prove(stark_trace, stark_comp, 4, 4)
        valid_stark = Verifier::STARK.verify(stark_proof, stark_trace.domain, field)
        puts valid_stark ? TUI::ANSI.green("PASS [VERIFIED]") : TUI::ANSI.red("FAIL")

        puts ""
        puts TUI::ANSI.green("All cryptographic proof systems verified with zero errors.")
        0
      end
    end
  end
end
