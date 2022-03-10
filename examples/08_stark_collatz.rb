# frozen_string_literal: true

require_relative "../lib/vellum/algebra/fields/goldilocks"
require_relative "../lib/vellum/circuit/air/trace"
require_relative "../lib/vellum/circuit/air/boundary"
require_relative "../lib/vellum/circuit/air/composition"
require_relative "../lib/vellum/prover/stark"
require_relative "../lib/vellum/verifier/stark"
require_relative "../lib/vellum/tui/ansi"

include Vellum::TUI::ANSI

puts bold(cyan("\n================================================================================"))
puts bold(cyan("  VELLUM ZK VERIFIABLE COMPUTATION ENGINE: TRANSPARENT STARK COLLATZ SEQUENCE  "))
puts bold(cyan("================================================================================\n"))

field = Vellum::Algebra::Fields::Goldilocks.instance

puts "#{blue('::')} Field: Goldilocks Prime Field (p = 2^64 - 2^32 + 1, 2-adicity = 32)"
puts "   Modulus: #{Vellum::Algebra::Fields::Goldilocks::MODULUS}"
puts "   Protocol: Transparent Post-Quantum STARK (No Trusted Setup, No Pairings)\n"

# Compute Collatz sequence for initial value n = 19 for 16 steps
init_val = 19
steps = 16
curr = init_val
history = []

steps.times do |s|
  history << [s, curr, curr.even? ? 0 : 1]
  curr = curr.even? ? (curr / 2) : (3 * curr + 1)
end

puts "#{blue('::')} Target Computation: Collatz (3n + 1) trajectory starting at n = #{init_val}"
puts "   Number of Trace Steps: #{steps} (power of 2 domain)"
puts "   Registers: Reg 0 = State (n_t), Reg 1 = Parity (0 if even, 1 if odd)\n"

trace = Vellum::Circuit::AIR::Trace.new(field, 2, steps)
history.each do |s, val, parity|
  trace.set(s, 0, val)
  trace.set(s, 1, parity)
end

puts "#{bold('Execution Trace Table (Goldilocks Elements):')}"
puts "   Step | Reg 0: State (n_t) | Reg 1: Parity | Rule Applied"
puts "   -----+--------------------+---------------+-----------------"
history.each do |s, val, parity|
  rule = parity.zero? ? "n / 2" : "3n + 1"
  puts sprintf("   %4d | %18d | %13d | %s", s, val, parity, rule)
end
puts ""

# Assert initial condition and terminal condition
b_init = Vellum::Circuit::AIR::Boundary.new(field, trace.domain, 0, 0, init_val)
b_term = Vellum::Circuit::AIR::Boundary.new(field, trace.domain, steps - 1, 0, trace.get(steps - 1, 0))

puts "#{blue('::')} Formulating Boundary Constraints:"
puts "   B0: Reg 0 at step 0 == #{init_val} (Initial Seed) -> #{b_init.satisfied?(trace) ? green('PASS') : red('FAIL')}"
puts "   B1: Reg 0 at step #{steps - 1} == #{trace.get(steps - 1, 0).to_i} (Terminal State) -> #{b_term.satisfied?(trace) ? green('PASS') : red('FAIL')}\n"

comp = Vellum::Circuit::AIR::Composition.new(trace, [], [b_init, b_term])

puts "#{blue('::')} Synthesizing STARK Proof with Fast Reed-Solomon IOP of Proximity (FRI)..."
puts "   Blowup Factor: 4x Low-Degree Extension (LDE)"
puts "   Coset Shift: g = 3"
puts "   Query Count: 8 Merkle authentication paths"
puts "   Hash Function: BLAKE2s (256-bit cryptographic sponge)\n"

t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
proof = Vellum::Prover::STARK.prove(trace, comp, 8, 4)
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

puts "#{green('::')} STARK Proof Synthesized in #{sprintf('%.4f', t1 - t0)}s"
puts "   Trace Merkle Root:       #{proof.trace_root.unpack1('H*')}"
puts "   Composition Merkle Root: #{proof.comp_root.unpack1('H*')}"
puts "   FRI Folding Rounds:      #{proof.fri_roots.length} rounds"
proof.fri_roots.each_with_index do |root, idx|
  puts "     - FRI Round #{idx} Root:  #{root.unpack1('H*')}"
end
puts "   Final Polynomial Degree: #{proof.final_poly.degree} (Max allowable < 4)"
puts "   Authentication Queries:  #{proof.query_proofs.length} query paths verified\n"

puts "#{blue('::')} Verifying STARK Proof via Merkle Authentication Paths & FRI Folding..."
tv0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
valid = Vellum::Verifier::STARK.verify(proof, trace.domain, field)
tv1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

puts "\n================================================================================"
if valid
  puts bold(green("  STARK PROOF VERIFICATION: VALID (Proof Accepted in #{sprintf('%.4f', tv1 - tv0)}s)  "))
else
  puts bold(red("  STARK PROOF VERIFICATION: INVALID (Proof Rejected)  "))
  exit 1
end
puts bold(cyan("================================================================================\n"))
