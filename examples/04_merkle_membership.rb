# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/crypto/merkle_tree"
require_relative "../lib/vellum/dsl/gadgets/merkle"

# Example 4: Zero-Knowledge Merkle Tree Membership Proof
# Proves that a secret leaf is included in a Merkle tree without revealing its position or value.
puts "=== Example 4: Merkle Tree Membership Proof ==="

field = Vellum::Algebra::Fields::BN254Scalar.instance
leaves = [field.element(101), field.element(202), field.element(303), field.element(404)]
tree = Vellum::Crypto::MerkleTree.new(leaves, :poseidon)
root = tree.root

target_index = 2
auth_proof = tree.prove(target_index)
puts "Merkle root: #{root}"
puts "Authenticating leaf #{leaves[target_index]} at index #{target_index}..."

circuit = Vellum.circuit do
  leaf = private_input(:leaf)
  sibling_0 = private_input(:sibling_0)
  sibling_1 = private_input(:sibling_1)
  dir_0 = private_input(:dir_0)
  dir_1 = private_input(:dir_1)
  expected_root = public_input(:root)

  computed_root = Vellum::DSL::Gadgets::MerkleGadget.verify_membership(
    self,
    leaf,
    [sibling_0, sibling_1],
    [dir_0, dir_1]
  )
  assert_equal(computed_root, expected_root, "merkle_root_matches")
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk, vk = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prove
inputs = {
  leaf: leaves[target_index],
  sibling_0: auth_proof.path[0][:sibling],
  sibling_1: auth_proof.path[1][:sibling],
  dir_0: auth_proof.path[0][:direction] == :right ? 0 : 1,
  dir_1: auth_proof.path[1][:direction] == :right ? 0 : 1,
  root: root
}

proof = circuit.prove(pk, inputs)
puts "Proof synthesized successfully."

# 3. Verify
valid = circuit.verify(vk, [root], proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
