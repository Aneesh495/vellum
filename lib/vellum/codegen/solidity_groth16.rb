# frozen_string_literal: true

module Vellum
  module Codegen
    # Generates production-ready, self-contained Solidity smart contracts
    # for verifying Groth16 zero-knowledge proofs on Ethereum and EVM-compatible chains.
    # Utilizes native EVM precompiles: ecAdd (0x06), ecMul (0x07), ecPairing (0x08).
    class SolidityGroth16
      def self.generate(vk, contract_name = "Groth16Verifier")
        ic_constants = vk.ic.each_with_index.map do |p, i|
          aff = p.to_affine
          "        vk.ic[#{i}] = Pairing.G1Point(#{aff.x}, #{aff.y});"
        end.join("\n")

        alpha = vk.alpha_g1.to_affine
        beta = vk.beta_g2.to_affine
        gamma = vk.gamma_g2.to_affine
        delta = vk.delta_g2.to_affine

        <<~SOLIDITY
          // SPDX-License-Identifier: MIT
          pragma solidity ^0.8.20;

          library Pairing {
              struct G1Point {
                  uint256 X;
                  uint256 Y;
              }

              struct G2Point {
                  uint256[2] X;
                  uint256[2] Y;
              }

              function negate(G1Point memory p) internal pure returns (G1Point memory) {
                  if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
                  uint256 q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
                  return G1Point(p.X, q - (p.Y % q));
              }

              function pairing(
                  G1Point[] memory p1,
                  G2Point[] memory p2
              ) internal view returns (bool) {
                  require(p1.length == p2.length, "Pairing array lengths mismatch");
                  uint256 elements = p1.length;
                  uint256 inputSize = elements * 6;
                  uint256[] memory input = new uint256[](inputSize);

                  for (uint256 i = 0; i < elements; i++) {
                      input[i * 6 + 0] = p1[i].X;
                      input[i * 6 + 1] = p1[i].Y;
                      input[i * 6 + 2] = p2[i].X[1];
                      input[i * 6 + 3] = p2[i].X[0];
                      input[i * 6 + 4] = p2[i].Y[1];
                      input[i * 6 + 5] = p2[i].Y[0];
                  }

                  uint256[1] memory out;
                  bool success;
                  assembly {
                      success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
                  }
                  require(success, "Pairing precompile call failed");
                  return out[0] == 1;
              }
          }

          contract #{contract_name} {
              using Pairing for *;

              struct VerifyingKey {
                  Pairing.G1Point alpha1;
                  Pairing.G2Point beta2;
                  Pairing.G2Point gamma2;
                  Pairing.G2Point delta2;
                  Pairing.G1Point[] ic;
              }

              struct Proof {
                  Pairing.G1Point a;
                  Pairing.G2Point b;
                  Pairing.G1Point c;
              }

              function verifyingKey() internal pure returns (VerifyingKey memory vk) {
                  vk.alpha1 = Pairing.G1Point(#{alpha.x}, #{alpha.y});
                  vk.beta2 = Pairing.G2Point([#{beta.x.coeffs[0]}, #{beta.x.coeffs[1]}], [#{beta.y.coeffs[0]}, #{beta.y.coeffs[1]}]);
                  vk.gamma2 = Pairing.G2Point([#{gamma.x.coeffs[0]}, #{gamma.x.coeffs[1]}], [#{gamma.y.coeffs[0]}, #{gamma.y.coeffs[1]}]);
                  vk.delta2 = Pairing.G2Point([#{delta.x.coeffs[0]}, #{delta.x.coeffs[1]}], [#{delta.y.coeffs[0]}, #{delta.y.coeffs[1]}]);
                  vk.ic = new Pairing.G1Point[](#{vk.ic.length});
          #{ic_constants}
              }

              function verifyProof(
                  Proof memory proof,
                  uint256[] memory input
              ) public view returns (bool) {
                  VerifyingKey memory vk = verifyingKey();
                  require(input.length + 1 == vk.ic.length, "Invalid public input length");

                  // Compute linear combination of public inputs: vk.ic[0] + sum(input[i] * vk.ic[i+1])
                  Pairing.G1Point memory vk_x = vk.ic[0];
                  for (uint256 i = 0; i < input.length; i++) {
                      // Perform ecMul and ecAdd precompile calls
                      uint256[3] memory mulInput;
                      mulInput[0] = vk.ic[i + 1].X;
                      mulInput[1] = vk.ic[i + 1].Y;
                      mulInput[2] = input[i];
                      Pairing.G1Point memory mulRes;
                      assembly {
                          if iszero(staticcall(sub(gas(), 2000), 7, mulInput, 0x60, mulRes, 0x40)) {
                              revert(0, 0)
                          }
                      }
                      uint256[4] memory addInput;
                      addInput[0] = vk_x.X;
                      addInput[1] = vk_x.Y;
                      addInput[2] = mulRes.X;
                      addInput[3] = mulRes.Y;
                      assembly {
                          if iszero(staticcall(sub(gas(), 2000), 6, addInput, 0x80, vk_x, 0x40)) {
                              revert(0, 0)
                          }
                      }
                  }

                  Pairing.G1Point[] memory p1 = new Pairing.G1Point[](4);
                  Pairing.G2Point[] memory p2 = new Pairing.G2Point[](4);

                  p1[0] = Pairing.negate(proof.a);
                  p2[0] = proof.b;

                  p1[1] = vk.alpha1;
                  p2[1] = vk.beta2;

                  p1[2] = vk_x;
                  p2[2] = vk.gamma2;

                  p1[3] = proof.c;
                  p2[3] = vk.delta2;

                  return Pairing.pairing(p1, p2);
              }
          }
        SOLIDITY
      end
    end
  end
end
