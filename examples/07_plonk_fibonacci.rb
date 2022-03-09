# frozen_string_literal: true

require_relative "../lib/vellum/algebra/pairing/bn254_pairing"
require_relative "../lib/vellum/crypto/kzg"
require_relative "../lib/vellum/circuit/plonkish/table"
require_relative "../lib/vellum/circuit/plonkish/copy_constraints"
require_relative "../lib/vellum/circuit/plonkish/gate"
require_relative "../lib/vellum/prover/plonk"
require_relative "../lib/vellum/verifier/plonk"
require_relative "../lib/vellum/tui/ansi"

include Vellum::TUI::ANSI

puts bold(cyan("\n================================================================================"))
puts bold(cyan("  VELLUM ZK VERIFIABLE COMPUTATION ENGINE: PLONK FIBONACCI PERMUTATION TRACE  "))
puts bold(cyan("================================================================================\n"))

pairing_engine = Vellum::Algebra::Pairing::BN254Pairing.instance
field = pairing_engine.fr

puts "#{blue('::')} Target Computation: 8 iterations of Fibonacci recurrence"
puts "   F(0) = 1, F(1) = 1, F(i+2) = F(i) + F(i+1)"
puts "   Arithmetization: Plonkish Trace Table with Add gates & copy-permutation arguments\n"

# Compute Fibonacci numbers
fib = [1, 1]
8.times { |i| fib << (fib[i] + fib[i + 1]) }

table = Vellum::Circuit::Plonkish::Table.new(field, 8)
gate_add = Vellum::Circuit::Plonkish::Gate.addition(field)
copy_pairs = []

8.times do |i|
  a_val = fib[i]
  b_val = fib[i + 1]
  c_val = fib[i + 2]
  table.add_row(gate_add, a_val, b_val, c_val)

  # Copy constraints between adjacent steps:
  # wire_b of step i == wire_a of step i + 1
  # wire_c of step i == wire_b of step i + 1
  if i < 7
    copy_pairs << [[i, 1], [i + 1, 0]] # b_i -> a_{i+1}
    copy_pairs << [[i, 2], [i + 1, 1]] # c_i -> b_{i+1}
  end
end

table.finalize!
puts "#{green('::')} Execution Trace Finalized: Domain Size = #{table.domain.size} roots of unity"
puts "   Trace satisfaction check: #{table.satisfied? ? green('SATISFIED') : red('UNSATISFIED')}\n"

puts "#{bold('Plonkish Trace Rows:')}"
puts "   Row | Gate Type | Wire A (F_i) | Wire B (F_i+1) | Wire C (F_i+2) | Gate Check"
puts "   ----+-----------+--------------+----------------+----------------+-----------"
table.num_rows.times do |r|
  a = table.wire_a[r].to_i
  b = table.wire_b[r].to_i
  c = table.wire_c[r].to_i
  gt = table.gates[r].gate_type
  sat = table.gates[r].satisfied?(table.wire_a[r], table.wire_b[r], table.wire_c[r])
  puts sprintf("   %3d | %-9s | %12d | %14d | %14d | %s", r, gt, a, b, c, sat ? green("OK") : red("FAIL"))
end
puts ""

puts "#{blue('::')} Constructing Copy Constraint Permutation Polynomials..."
copy_constraints = Vellum::Circuit::Plonkish::CopyConstraints.new(table.domain)
copy_constraints.build_permutation_polynomials(copy_pairs)
puts "   Permutation polynomials sigma_1, sigma_2, sigma_3 constructed."
puts "   Enforced copy transitions: #{copy_pairs.length} wiring identities\n"

puts "#{blue('::')} Generating Universal KZG Structured Reference String (SRS)..."
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
srs = Vellum::Crypto::KZG.setup(table.domain.size * 4, pairing_engine)
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "   Universal SRS generated up to degree #{srs.max_degree} in #{sprintf('%.3f', t1 - t0)}s\n"

puts "#{blue('::')} Synthesizing Plonk Zero-Knowledge Proof (5 Rounds)..."
tp0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
proof = Vellum::Prover::Plonk.prove(table, copy_constraints, srs)
tp1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "   Proof synthesized successfully in #{sprintf('%.3f', tp1 - tp0)}s"
puts "   Round 1 Wire Commitments: [a]_1, [b]_1, [c]_1"
puts "   Round 2 Permutation Accumulator: [z]_1"
puts "   Round 3 Quotient Chunks: [t_lo]_1, [t_mid]_1, [t_hi]_1"
puts "   Round 4 Evaluation Openings: a(zeta), b(zeta), c(zeta), s1(zeta), s2(zeta), z(zeta*omega)"
puts "   Round 5 KZG Openings: [W_zeta]_1, [W_zeta_omega]_1\n"

puts "#{blue('::')} Verifying Plonk Proof using BN254 Bilinear Pairings..."
tv0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
valid = Vellum::Verifier::Plonk.verify(proof, srs, table.domain)
tv1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

puts "\n================================================================================"
if valid
  puts bold(green("  PLONK PROOF VERIFICATION: VALID (Proof Accepted in #{sprintf('%.4f', tv1 - tv0)}s)  "))
else
  puts bold(red("  PLONK PROOF VERIFICATION: INVALID (Proof Rejected)  "))
  exit 1
end
puts bold(cyan("================================================================================\n"))
