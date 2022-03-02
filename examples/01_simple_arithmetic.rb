# frozen_string_literal: true

require_relative "../lib/vellum"

# Example 1: Simple Non-Linear Arithmetic Circuit
# Proves knowledge of private x such that x^3 + x + 5 == 35 (solution: x = 3)
puts "=== Example 1: Cubic Equation Zero-Knowledge Proof ==="

circuit = Vellum.circuit do
  x = private_input(:x)
  out = public_input(:out)

  x2 = x * x
  x3 = x2 * x
  result = x3 + x + 5

  assert_equal(result, out, "cubic_relation")
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk, vk = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prover
witness_inputs = { x: 3, out: 35 }
proof = circuit.prove(pk, witness_inputs)
puts "Proof synthesized successfully."

# 3. Verifier
valid = circuit.verify(vk, [35], proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
