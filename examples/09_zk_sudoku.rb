# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/dsl/gadgets/sudoku"
require_relative "../lib/vellum/tui/ansi"

include Vellum::TUI::ANSI

puts bold(cyan("\n================================================================================"))
puts bold(cyan("  VELLUM ZK VERIFIABLE COMPUTATION ENGINE: ZERO-KNOWLEDGE SUDOKU VERIFICATION  "))
puts bold(cyan("================================================================================\n"))

# 4x4 Mini-Sudoku Grid
# Solution:
# [ 1, 2, 3, 4 ]
# [ 3, 4, 1, 2 ]
# [ 2, 1, 4, 3 ]
# [ 4, 3, 2, 1 ]
#
# Public Clues (Masked puzzle):
# [ 1, ., 3, . ]
# [ ., 4, ., 2 ]
# [ 2, ., 4, . ]
# [ ., 3, ., 1 ]

solution = [
  [1, 2, 3, 4],
  [3, 4, 1, 2],
  [2, 1, 4, 3],
  [4, 3, 2, 1]
]

public_clues = {
  [0, 0] => 1,
  [0, 2] => 3,
  [1, 1] => 4,
  [1, 3] => 2,
  [2, 0] => 2,
  [2, 2] => 4,
  [3, 1] => 3,
  [3, 3] => 1
}

puts "#{blue('::')} Public Puzzle Configuration (Masked Board):"
puts "   +---+---+---+---+"
4.times do |r|
  row_str = "   |"
  4.times do |c|
    val = public_clues[[r, c]] ? yellow(" #{public_clues[[r, c]]} ") : dim(" . ")
    row_str += "#{val}|"
  end
  puts row_str
  puts "   +---+---+---+---+"
end
puts "   Yellow digits indicate public clues; '.' represents secret solution cells.\n"

puts "#{blue('::')} Compiling Sudoku R1CS Verification Circuit..."
circuit = Vellum.circuit do
  cells = Array.new(4) { Array.new(4) }
  4.times do |r|
    4.times do |c|
      cells[r][c] = private_input("cell_#{r}_#{c}".to_sym)
    end
  end

  # Map clues to public inputs
  clue_signals = {}
  public_clues.each do |coord, _|
    r, c = coord
    clue_signals[coord] = public_input("clue_#{r}_#{c}".to_sym)
  end

  Vellum::DSL::Gadgets::SudokuGadget.verify_mini_grid(self, cells, clue_signals)
end

puts "#{green('::')} Circuit Compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."
puts "   - 4 Row permutation constraints (sum = 10, prod = 24)"
puts "   - 4 Column permutation constraints (sum = 10, prod = 24)"
puts "   - 4 2x2 Box permutation constraints (sum = 10, prod = 24)"
puts "   - 8 Public clue binding equality assertions\n"

puts "#{blue('::')} Executing Groth16 Trusted Setup (BN254 Pairing Curve)..."
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
pk, vk = circuit.setup
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "   Proving Key (PK) and Verifying Key (VK) generated in #{sprintf('%.3f', t1 - t0)}s\n"

puts "#{blue('::')} Synthesizing Zero-Knowledge Witness from Private Solution..."
inputs = {}
public_clues.each do |coord, val|
  r, c = coord
  inputs["clue_#{r}_#{c}".to_sym] = val
end
4.times do |r|
  4.times do |c|
    inputs["cell_#{r}_#{c}".to_sym] = solution[r][c]
  end
end

t_p0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
proof = circuit.prove(pk, inputs)
t_p1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "   Groth16 Zero-Knowledge Proof synthesized in #{sprintf('%.3f', t_p1 - t_p0)}s"
puts "   Proof Points: [A]_1 in G1, [B]_2 in G2, [C]_1 in G1\n"

puts "#{blue('::')} Verifying Proof against Public Clues via Bilinear Pairing Engine..."
pub_input_values = public_clues.values

t_v0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
valid = circuit.verify(vk, pub_input_values, proof)
t_v1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)

puts "\n================================================================================"
if valid
  puts bold(green("  SUDOKU ZK PROOF VERIFICATION: VALID (Proof Accepted in #{sprintf('%.4f', t_v1 - t_v0)}s)  "))
  puts "  The prover has proven knowledge of a valid Sudoku solution satisfying"
  puts "  all rows, columns, and 2x2 boxes, matching the public clues, WITHOUT revealing"
  puts "  any secret cell entries!"
else
  puts bold(red("  SUDOKU ZK PROOF VERIFICATION: INVALID (Proof Rejected)  "))
  exit 1
end
puts bold(cyan("================================================================================\n"))
