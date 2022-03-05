# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/dsl/gadgets/poseidon"
require_relative "../lib/vellum/crypto/poseidon/sponge"

# Example 3: Zero-Knowledge Poseidon Hash Preimage Proof
# Proves knowledge of private preimages (secret_a, secret_b) that hash to a known public digest.
puts "=== Example 3: Poseidon Hash Preimage Proof ==="

field = Vellum::Algebra::Fields::BN254Scalar.instance
secret_a = field.element(123456789)
secret_b = field.element(987654321)
expected_hash = Vellum::Crypto::Poseidon.hash_2(secret_a, secret_b, field: field)

puts "Target public digest: #{expected_hash}"

circuit = Vellum.circuit do
  a = private_input(:secret_a)
  b = private_input(:secret_b)
  digest = public_input(:hash)

  computed_digest = Vellum::DSL::Gadgets::PoseidonGadget.hash_2(self, a, b)
  assert_equal(computed_digest, digest, "preimage_digest_match")
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk, vk = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prove
witness_inputs = { secret_a: secret_a, secret_b: secret_b, hash: expected_hash }
proof = circuit.prove(pk, witness_inputs)
puts "Proof synthesized successfully."

# 3. Verify
valid = circuit.verify(vk, [expected_hash], proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
