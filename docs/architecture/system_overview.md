# Vellum: Architecture and System Overview

Vellum is a zero-knowledge proof synthesis and verifiable computation engine engineered from first principles in Ruby. It provides an end-to-end framework for expressing arbitrary computational claims, lowering them into intermediate representations, and compiling them into succinct non-interactive zero-knowledge arguments (zk-SNARKs and zk-STARKs).

```
+-------------------------------------------------------------------------+
|                         High-Level Circuit DSL                          |
|    (Variables, Constraints, Binary/Range Gadgets, Poseidon, EdDSA)      |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                  Intermediate Representations (IR)                      |
|   +-----------------------+                    +--------------------+   |
|   |   R1CS Constraint     |                    |  Plonkish Trace /  |   |
|   |       System          |                    |  AIR Constraints   |   |
|   +-----------------------+                    +--------------------+   |
|               |                                          |              |
|               v                                          |              |
|   +-----------------------+                              |              |
|   | Quadratic Arithmetic  |                              |              |
|   |      Program (QAP)    |                              |              |
|   +-----------------------+                              |              |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                         Proof System Backends                           |
|   +-------------------+  +--------------------+  +------------------+   |
|   |      Groth16      |  |       Plonk        |  |      STARK       |   |
|   | (Pairing-Based)   |  | (KZG Polynomial)   |  | (Transparent/FRI)|   |
|   +-------------------+  +--------------------+  +------------------+   |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                   Verification & Code Generation                        |
|   +-------------------+  +--------------------+  +------------------+   |
|   | Native Ruby Engine|  | Solidity Verifier  |  |   C99 Portable   |   |
|   | (In-Memory Check) |  | (EVM Precompiles)  |  |     Verifier     |   |
|   +-------------------+  +--------------------+  +------------------+   |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                       Cryptographic Foundations                         |
|   +-------------------+  +--------------------+  +------------------+   |
|   | Finite Field Core |  |  Elliptic Curves   |  |  Pairing Engine  |   |
|   | (Fp, Fp2, Fp6,    |  |  (BN254, BLS12-381,|  |  (Miller Loop,   |   |
|   |  Fp12, Goldilocks)|  |   BabyJubJub)      |  |  Final Expon.)   |   |
|   +-------------------+  +--------------------+  +------------------+   |
+-------------------------------------------------------------------------+
```

## Design Philosophy

1. **Zero External Runtime Dependencies**: The core algebraic stack, polynomial arithmetic, fast Fourier transforms (NTT), elliptic curve operations, pairing algorithms, cryptographic hashes, and proof systems are implemented in pure Ruby. The system runs out of the box on any standard Ruby runtime without requiring external C libraries or packages.
2. **Mathematical Rigor and Formal Equivalence**: Every layer directly reflects its mathematical definition. Field extensions are structured as field quotients, polynomial commitments implement Schwartz-Zippel bounds, and proof systems follow their authoritative cryptographic specifications (Groth16 Eurocrypt 2016, Plonk ePrint 2019/953, STARK ePrint 2018/046).
3. **Pluggable Arithmetization**: Rather than locking developers into a single intermediate representation, Vellum supports multiple compilation targets:
   - Rank-1 Constraint Systems (R1CS) for Groth16.
   - Plonkish execution trace grids with custom gate selectors and copy-permutation arguments.
   - Algebraic Intermediate Representation (AIR) with transition and boundary constraints for STARKs.
4. **Transparent Verification Targets**: Once an arithmetic circuit is proved, Vellum generates deployable verifiers targeting both EVM smart contracts (Solidity with pairing precompile support) and self-contained C99 libraries with zero dynamic allocations.

## Subsystem Breakdown

### 1. Algebraic Kernel (`lib/vellum/algebra/`)
The foundation of Vellum is an algebraic kernel providing:
- Arbitrary-precision prime fields (`PrimeField`) with Montgomery reduction and Tonelli-Shanks modular square roots.
- Complex extension towers ($F_{p^2}$, $F_{p^6}$, $F_{p^{12}}$) supporting optimal Ate pairings.
- Short Weierstrass elliptic curves over prime fields and extension fields with projective and Jacobian coordinate arithmetic.
- Twisted Edwards curves over prime fields with dedicated birational mapping and fast point addition.
- Bilinear pairing engines implementing line functions, Miller loops, Frobenius twists, and final exponentiations.
- Dense polynomial operations with Fast Fourier Transforms (Number Theoretic Transform - NTT) in $O(n \log n)$ time.

### 2. Intermediate Representations (`lib/vellum/circuit/`)
Circuits are translated into formal mathematical structures:
- `Variable` and `LinearCombination`: Symbolic representation of affine constraints over field elements.
- `R1CS`: System of rank-1 constraints satisfying $(A \cdot w) \circ (B \cdot w) = C \cdot w$.
- `R1CSOptimizer`: Constraint deduction, dead-code elimination, and linear substitution pass reducing constraint counts.
- `QAP`: Quadratic Arithmetic Program converting R1CS matrices into polynomials via Lagrange interpolation over roots of unity.
- `PlonkishTrace`: 2D execution matrix with selector polynomials and permutation arguments over cycles.
- `AIR`: Algebraic Intermediate Representation defining transition polynomials across adjacent computational states.

### 3. Proof Systems (`lib/vellum/prover/` and `lib/vellum/verifier/`)
- **Groth16**:
  - Setup: Structured reference string generation (proving and verifying keys).
  - Prover: Witness evaluation, multi-scalar multiplication (MSM) in $G_1$ and $G_2$, random blinding factor injection ($r, s$).
  - Verifier: Multi-pairing check $e(A, B) = e(\alpha, \beta) + e(x \cdot \gamma, \delta) + e(C, \delta)$.
- **Plonk**:
  - Permutation argument: Grand product polynomial $Z(X)$ enforcing equality across copy constraints.
  - Gate arithmetic: Custom gate evaluation with selector polynomials $q_L, q_R, q_O, q_M, q_C$.
  - Polynomial commitment: KZG commitment scheme over BN254 with batched evaluation openings.
- **STARK**:
  - Execution trace: Low-degree extension (LDE) evaluated over an evaluation domain.
  - Constraint evaluation: Transition and boundary quotient polynomial composition.
  - FRI: Fast Reed-Solomon Interactive Oracle Proof of Proximity verifying low degree without pairings or trusted setups.

### 4. High-Level DSL and Gadget Library (`lib/vellum/dsl/`)
A declarative Ruby DSL allows developers to write intuitive cryptographic circuits:
- Bit decomposition, range checks, and boolean enforcement.
- Equality comparisons and multiplexers.
- In-circuit algebraic hash functions (Poseidon, Rescue, GMiMC).
- Merkle membership proofs.
- BabyJubJub EdDSA digital signature verification.

### 5. Code Generation (`lib/vellum/codegen/`)
- `SolidityVerifier`: Emits standalone, zero-dependency Solidity smart contracts compatible with Ethereum precompiles (addresses `0x06`, `0x07`, `0x08`).
- `CVerifier`: Emits ANSI C99 verification logic suitable for embedded, mobile, or native systems.
