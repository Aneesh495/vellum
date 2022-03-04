# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/dsl/gadgets/range"

# Example 2: Zero-Knowledge Range Proof
# Proves that a secret balance lies within [100, 10000] without revealing the exact balance.
puts "=== Example 2: Bounded Range Zero-Knowledge Proof ==="

circuit = Vellum.circuit do
  balance = private_input(:balance)
  is_valid = public_input(:valid)

  # Check that 100 <= balance <= 10000 using 14-bit decomposition (up to 16384)
  Vellum::DSL::Gadgets::RangeProofGadget.assert_in_range(self, balance, 100, 10000, 14)
  assert_equal(is_valid, 1, "valid_range_flag")
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk, vk = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prove
witness_inputs = { balance: 2500, valid: 1 }
proof = circuit.prove(pk, witness_inputs)
puts "Proof synthesized successfully."

# 3. Verify
valid = circuit.verify(vk, [1], proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
