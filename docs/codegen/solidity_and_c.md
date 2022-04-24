# Vellum: Automated Verifier Code Generation (Solidity and ANSI C99)

A critical bottleneck in zero-knowledge engineering is bridging high-level circuit development with target deployment environments. Vellum eliminates handwritten verifiers by compiling cryptographic verification logic directly into production-grade Solidity smart contracts and standalone C99 binaries.

---

## 1. EVM Smart Contract Generation (Solidity)

The `Vellum::Codegen::SolidityVerifier` compiles a Groth16 verifying key into an optimized, self-contained Solidity contract compatible with modern EVM compiler toolchains (Solidity >= 0.8.0).

### 1.1 EVM Precompiles Utilized
Ethereum Byzantium and Istanbul hard forks introduced cryptographic precompiles for the BN254 (alt_bn128) curve:
- **`ecAdd` (`0x06`)**: $G_1$ Point Addition. Gas cost: 150 gas.
- **`ecMul` (`0x07`)**: $G_1$ Scalar Multiplication. Gas cost: 6,000 gas.
- **`ecPairing` (`0x08`)**: Multi-Pairing Check. Gas cost: $45,000 + 34,000 \cdot k$ gas (where $k$ is the number of point pairs).

### 1.2 Gas-Optimized Assembly Pipeline
The generated contract evaluates public input linear combinations and executes the multi-pairing check in a single assembly block:
```solidity
function verifyProof(
    uint256[2] memory a,
    uint256[2][2] memory b,
    uint256[2] memory c,
    uint256[] memory input
) public view returns (bool r) {
    // 1. Verify inputs are elements of the scalar field Fr
    // 2. Accumulate public inputs IC = IC[0] + sum(input[i] * IC[i+1]) using ecMul and ecAdd
    // 3. Negate proof point A to check e(-A, B) * e(alpha, beta) * e(IC, gamma) * e(C, delta) == 1
    // 4. Pack 4 point pairs (24 words, 768 bytes) and invoke staticcall to precompile 0x08
}
```

By batching all four pairings into a single `staticcall` to `0x08`, on-chain gas consumption is reduced to approximately 180,000 - 210,000 gas total, regardless of circuit constraint complexity.

---

## 2. Portable ANSI C99 Verifier Generation

For resource-constrained embedded systems, mobile applications, and native backends, `Vellum::Codegen::CVerifier` emits a single self-contained C source and header file.

### 2.1 Architectural Invariants
- **Zero Dynamic Allocation**: All intermediate buffers, coordinates, and limb structures are allocated on the stack. No calls to `malloc`, `free`, or runtime allocators.
- **No External Dependencies**: Contains embedded constant-time modular arithmetic, 256-bit limb operations, Jacobian point addition, line functions, and Miller loop logic.
- **Deterministic Constant-Time Execution**: Arithmetic paths avoid branching on secret data to mitigate microarchitectural side channels.

### 2.2 Interface and Signature
```c
#include "vellum_verifier.h"

// Returns 1 if proof is valid for the given public inputs, 0 otherwise
int vellum_verify(
    const vellum_g1_t *proof_a,
    const vellum_g2_t *proof_b,
    const vellum_g1_t *proof_c,
    const uint64_t *public_inputs,
    size_t num_inputs
);
```
The emitted code compiles cleanly under `clang -Wall -Wextra -pedantic -std=c99` and `gcc` with zero warnings.
