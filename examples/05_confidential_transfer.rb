# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/dsl/gadgets/range"
require_relative "../lib/vellum/dsl/gadgets/poseidon"
require_relative "../lib/vellum/crypto/poseidon/sponge"

# Example 5: Confidential Asset Transfer Proof
# Proves valid balance transfer between Alice and Bob:
# - Alice transfers private `amount` to Bob
# - Proves solvency (no negative balances, no overdraft)
# - Validates state transition across 4 cryptographic Poseidon commitments
puts "=== Example 5: Confidential Asset Transfer Proof ==="

field = Vellum::Algebra::Fields::BN254Scalar.instance

alice_bal_old = 500
bob_bal_old = 200
amount = 150
alice_bal_new = alice_bal_old - amount # 350
bob_bal_new = bob_bal_old + amount     # 350

alice_salt_old = 11111
alice_salt_new = 22222
bob_salt_old = 33333
bob_salt_new = 44444

comm_alice_old = Vellum::Crypto::Poseidon.hash_2(field.element(alice_bal_old), field.element(alice_salt_old), field: field)
comm_alice_new = Vellum::Crypto::Poseidon.hash_2(field.element(alice_bal_new), field.element(alice_salt_new), field: field)
comm_bob_old = Vellum::Crypto::Poseidon.hash_2(field.element(bob_bal_old), field.element(bob_salt_old), field: field)
comm_bob_new = Vellum::Crypto::Poseidon.hash_2(field.element(bob_bal_new), field.element(bob_salt_new), field: field)

puts "Alice commitment: #{comm_alice_old} -> #{comm_alice_new}"
puts "Bob commitment:   #{comm_bob_old} -> #{comm_bob_new}"

circuit = Vellum.circuit do
  a_bal_old = private_input(:a_bal_old)
  a_salt_old = private_input(:a_salt_old)
  a_salt_new = private_input(:a_salt_new)

  b_bal_old = private_input(:b_bal_old)
  b_salt_old = private_input(:b_salt_old)
  b_salt_new = private_input(:b_salt_new)

  transfer_amount = private_input(:amount)

  pub_comm_a_old = public_input(:comm_a_old)
  pub_comm_a_new = public_input(:comm_a_new)
  pub_comm_b_old = public_input(:comm_b_old)
  pub_comm_b_new = public_input(:comm_b_new)

  # Check commitments
  c_a_old = Vellum::DSL::Gadgets::PoseidonGadget.hash_2(self, a_bal_old, a_salt_old)
  assert_equal(c_a_old, pub_comm_a_old, "comm_a_old_match")

  a_bal_new = a_bal_old - transfer_amount
  c_a_new = Vellum::DSL::Gadgets::PoseidonGadget.hash_2(self, a_bal_new, a_salt_new)
  assert_equal(c_a_new, pub_comm_a_new, "comm_a_new_match")

  c_b_old = Vellum::DSL::Gadgets::PoseidonGadget.hash_2(self, b_bal_old, b_salt_old)
  assert_equal(c_b_old, pub_comm_b_old, "comm_b_old_match")

  b_bal_new = b_bal_old + transfer_amount
  c_b_new = Vellum::DSL::Gadgets::PoseidonGadget.hash_2(self, b_bal_new, b_salt_new)
  assert_equal(c_b_new, pub_comm_b_new, "comm_b_new_match")

  # Solvency: transfer_amount in [0, 16383], a_bal_new in [0, 16383]
  assert_range(transfer_amount, 14, "transfer_range")
  assert_range(a_bal_new, 14, "solvency_range")
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk, vk = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prove
inputs = {
  a_bal_old: alice_bal_old,
  a_salt_old: alice_salt_old,
  a_salt_new: alice_salt_new,
  b_bal_old: bob_bal_old,
  b_salt_old: bob_salt_old,
  b_salt_new: bob_salt_new,
  amount: amount,
  comm_a_old: comm_alice_old,
  comm_a_new: comm_alice_new,
  comm_b_old: comm_bob_old,
  comm_b_new: comm_bob_new
}

proof = circuit.prove(pk, inputs)
puts "Proof synthesized successfully."

# 3. Verify
public_inputs = [comm_alice_old, comm_alice_new, comm_bob_old, comm_bob_new]
valid = circuit.verify(vk, public_inputs, proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
