# frozen_string_literal: true

require_relative "../lib/vellum"
require_relative "../lib/vellum/crypto/babyjubjub_eddsa"
require_relative "../lib/vellum/dsl/gadgets/eddsa"

# Example 6: In-Circuit BabyJubJub EdDSA Signature Verification
# Proves knowledge of a valid EdDSA digital signature on message M
# under public key A, completely synthesized into an R1CS constraint system.
puts "=== Example 6: In-Circuit EdDSA Signature Proof ==="

sk = 123456789
message = 42
pk = Vellum::Crypto::BabyJubJubEdDSA.public_key(sk).to_affine
sig = Vellum::Crypto::BabyJubJubEdDSA.sign(sk, message)
r_aff = sig.r_point.to_affine

puts "Signer public key: (#{pk.x}, #{pk.y})"
puts "Signature R: (#{r_aff.x}, #{r_aff.y})"
puts "Signature S: #{sig.s_scalar}"
puts "Native EdDSA verification: #{Vellum::Crypto::BabyJubJubEdDSA.verify(pk, message, sig)}"

circuit = Vellum.circuit do
  ax = public_input(:ax)
  ay = public_input(:ay)
  msg = public_input(:msg)

  rx = private_input(:rx)
  ry = private_input(:ry)
  s = private_input(:s)

  # In-circuit signature validation: checks curve equations and Poseidon challenge
  h = Vellum::DSL::Gadgets::EdDSAGadget.verify(self, ax, ay, rx, ry, s, msg)
end

puts "Circuit compiled: #{circuit.num_constraints} constraints, #{circuit.num_variables} wires."

# 1. Setup
pk_snark, vk_snark = circuit.setup
puts "Groth16 setup completed."

# 2. Witness synthesis & Prove
inputs = {
  ax: pk.x,
  ay: pk.y,
  msg: message,
  rx: r_aff.x,
  ry: r_aff.y,
  s: sig.s_scalar
}

proof = circuit.prove(pk_snark, inputs)
puts "Proof synthesized successfully."

# 3. Verify
public_inputs = [pk.x, pk.y, message]
valid = circuit.verify(vk_snark, public_inputs, proof)
puts "Proof verification result: #{valid ? 'VALID (Proof Accepted)' : 'INVALID'}"
raise "Verification failed" unless valid
