# frozen_string_literal: true

require "benchmark"
require_relative "../lib/vellum"
require_relative "../lib/vellum/algebra/fields/bn254_scalar"
require_relative "../lib/vellum/algebra/fields/bn254_base"
require_relative "../lib/vellum/algebra/curves/bn254_g1"
require_relative "../lib/vellum/algebra/curves/bn254_g2"
require_relative "../lib/vellum/algebra/pairing/bn254_pairing"
require_relative "../lib/vellum/algebra/ntt"
require_relative "../lib/vellum/crypto/poseidon/sponge"
require_relative "../lib/vellum/crypto/blake2s"

module Vellum
  module Benchmarks
    class Suite
      def self.run
        puts "=" * 70
        puts "  VELLUM ZERO-KNOWLEDGE ENGINE: PERFORMANCE BENCHMARK SUITE"
        puts "=" * 70
        puts

        bench_finite_fields
        bench_elliptic_curves
        bench_hash_functions
        bench_ntt
        bench_groth16_pipeline

        puts "=" * 70
        puts "  BENCHMARK SUITE COMPLETED SUCCESSFULLY"
        puts "=" * 70
      end

      def self.bench_finite_fields
        puts "[1/5] Benchmarking Finite Field Arithmetic (BN254 Fr & Fq)..."
        fr = Vellum::Algebra::Fields::BN254Scalar.instance
        a = fr.element(1234567890123456789)
        b = fr.element(9876543210987654321)

        iterations = 50_000
        bm = Benchmark.measure do
          iterations.times { a * b }
        end
        ops_sec = (iterations / bm.real).to_i
        puts "  - Multiplications (Fr): #{iterations} ops in #{bm.real.round(3)}s (~#{ops_sec} ops/sec)"
        puts
      end

      def self.bench_elliptic_curves
        puts "[2/5] Benchmarking Elliptic Curve Operations (BN254 G1)..."
        g1 = Vellum::Algebra::Curves::BN254G1.instance
        p1 = g1.generator

        iterations = 5_000
        bm = Benchmark.measure do
          iterations.times { p1.double }
        end
        ops_sec = (iterations / bm.real).to_i
        puts "  - G1 Jacobian Doublings: #{iterations} ops in #{bm.real.round(3)}s (~#{ops_sec} ops/sec)"
        puts
      end

      def self.bench_hash_functions
        puts "[3/5] Benchmarking Algebraic & Symmetric Hash Functions..."
        fr = Vellum::Algebra::Fields::BN254Scalar.instance
        input = [fr.element(42), fr.element(99)]

        iterations = 500
        bm = Benchmark.measure do
          iterations.times { Vellum::Crypto::Poseidon.hash(input) }
        end
        ops_sec = (iterations / bm.real).to_i
        puts "  - Poseidon (width=3): #{iterations} hashes in #{bm.real.round(3)}s (~#{ops_sec} hashes/sec)"

        data = "Vellum Cryptographic Engine Test Message"
        bm_b2 = Benchmark.measure do
          iterations.times { Vellum::Crypto::Blake2s.digest(data) }
        end
        ops_sec_b2 = (iterations / bm_b2.real).to_i
        puts "  - BLAKE2s: #{iterations} digests in #{bm_b2.real.round(3)}s (~#{ops_sec_b2} digests/sec)"
        puts
      end

      def self.bench_ntt
        puts "[4/5] Benchmarking Number Theoretic Transform (NTT)..."
        field = Vellum::Algebra::Fields::BN254Scalar.instance
        require_relative "../lib/vellum/algebra/evaluation_domain"
        [256, 1024].each do |n|
          domain = Vellum::Algebra::EvaluationDomain.new(field, n)
          poly = Array.new(n) { |i| field.element(i + 1) }
          bm = Benchmark.measure do
            Vellum::Algebra::NTT.forward(poly, domain)
          end
          puts "  - Forward NTT (n=#{n}): #{bm.real.round(4)}s"
        end
        puts
      end

      def self.bench_groth16_pipeline
        puts "[5/5] Benchmarking End-to-End Groth16 Prover & Verifier..."
        circuit = Vellum.circuit do
          x = private_input(:x)
          y = public_input(:y)
          x2 = x * x
          x3 = x2 * x
          res = x3 + x + 5
          assert_equal(res, y)
        end

        pk, vk = nil, nil
        t_setup = Benchmark.measure { pk, vk = circuit.setup }
        puts "  - Trusted Setup: #{t_setup.real.round(4)}s"

        witness_inputs = { x: 3, y: 35 }
        proof = nil
        t_prove = Benchmark.measure { proof = circuit.prove(pk, witness_inputs) }
        puts "  - Proof Generation: #{t_prove.real.round(4)}s"

        valid = false
        t_verify = Benchmark.measure { valid = circuit.verify(vk, [35], proof) }
        puts "  - Verification: #{t_verify.real.round(4)}s (Accepted: #{valid})"
        puts
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Vellum::Benchmarks::Suite.run
end
