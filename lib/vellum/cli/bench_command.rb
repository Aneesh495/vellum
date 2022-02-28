# frozen_string_literal: true

require_relative "base"
require_relative "../algebra/fields/bn254_scalar"
require_relative "../algebra/curves/bn254_g1"
require_relative "../algebra/curves/bn254_g2"
require_relative "../algebra/msm"
require_relative "../algebra/evaluation_domain"
require_relative "../algebra/ntt"
require_relative "../crypto/poseidon/sponge"
require_relative "../utils/timing"

module Vellum
  module CLI
    class BenchCommand < Base
      def execute
        puts TUI::ANSI.bold("=== Vellum Cryptographic Benchmark Suite ===")
        puts ""

        field = Algebra::Fields::BN254Scalar.instance
        g1 = Curves::BN254G1.instance
        g2 = Curves::BN254G2.instance

        # 1. Finite field multiplications
        n_field = 10_000
        a = field.random_element
        b = field.random_element
        _, ms_field = Utils::Timing.measure do
          n_field.times { a * b }
        end
        ops_per_sec = (n_field / (ms_field / 1000.0)).round
        puts "Finite Field Fr Mul:      #{ms_field.round(2)} ms for #{n_field} ops (#{ops_per_sec} ops/sec)"

        # 2. G1 Scalar Multiplication
        n_g1 = 100
        gen1 = g1.generator
        s = field.random_element
        _, ms_g1 = Utils::Timing.measure do
          n_g1.times { gen1 * s }
        end
        puts "BN254 G1 Scalar Mul:      #{ms_g1.round(2)} ms for #{n_g1} ops (#{(n_g1 / (ms_g1 / 1000.0)).round} ops/sec)"

        # 3. Pippenger MSM (128 points)
        msm_size = 128
        points = Array.new(msm_size) { gen1 * field.random_element }
        scalars = Array.new(msm_size) { field.random_element }
        _, ms_msm = Utils::Timing.measure do
          Algebra::MSM.pippenger(points, scalars)
        end
        puts "Pippenger MSM (128 pts):  #{ms_msm.round(2)} ms"

        # 4. NTT (size 512)
        ntt_size = 512
        domain = Algebra::EvaluationDomain.new(field, ntt_size)
        coeffs = Array.new(ntt_size) { field.random_element }
        _, ms_ntt = Utils::Timing.measure do
          Algebra::NTT.forward(coeffs, domain)
        end
        puts "Radix-2 NTT (512 points): #{ms_ntt.round(2)} ms"

        # 5. Poseidon 2-to-1 Hash
        n_hash = 100
        h1 = field.random_element
        h2 = field.random_element
        _, ms_hash = Utils::Timing.measure do
          n_hash.times { Crypto::Poseidon.hash_2(h1, h2) }
        end
        puts "Poseidon Hash (2-to-1):   #{ms_hash.round(2)} ms for #{n_hash} hashes (#{(n_hash / (ms_hash / 1000.0)).round} hashes/sec)"

        puts ""
        puts TUI::ANSI.green("All benchmarks completed successfully.")
        0
      end
    end
  end
end
