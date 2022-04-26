# Vellum

```
 _    __     ____
| |  / /__  / / /_  ______ ___
| | / / _ \/ / / / / / __ `__ \
| |/ /  __/ / / /_/ / / / / / /
|___/\___/_/_/\__,_/_/ /_/ /_/
```

> **A zero-dependency zero-knowledge proof synthesis and verifiable computation engine engineered from first principles in Ruby.**

Vellum is an end-to-end cryptographic engine for compiling arbitrary computational relations into succinct, non-interactive zero-knowledge arguments (zk-SNARKs and zk-STARKs). It features an algebraic core supporting prime fields, tower extensions, short Weierstrass and twisted Edwards elliptic curves, pairing engines, polynomial rings, and Number Theoretic Transforms (NTT), alongside modular proof system backends including Groth16, Plonk, and STARKs.

---

## Architecture

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
```

---

## Key Features

- **Pure Ruby Algebraic Foundations**: Implements arbitrary-precision Galois fields $\mathbb{F}_p$, field extension towers ($\mathbb{F}_{p^2} \to \mathbb{F}_{p^6} \to \mathbb{F}_{p^{12}}$), and the 64-bit Goldilocks field without external runtime dependencies.
- **Elliptic Curve Arithmetic**: Full projective and Jacobian models for BN254 (alt_bn128), BLS12-381, and BabyJubJub with Pippenger multi-scalar multiplication (MSM).
- **Pairing Engine**: Optimal Ate pairings over BN254 and BLS12-381 with custom Miller loops, Frobenius endomorphisms, cyclotomic squaring, and hard-to-easy final exponentiation decomposition.
- **Polynomials & NTT**: In-place radix-2 Cooley-Tukey Number Theoretic Transforms, coset evaluations, barycentric Lagrange interpolation, and polynomial Euclidean division.
- **Multi-Arithmetization IR**: Compiles circuits to Rank-1 Constraint Systems (R1CS), Quadratic Arithmetic Programs (QAP), Plonkish execution traces with permutation arguments, and Algebraic Intermediate Representations (AIR).
- **Three Proof System Backends**:
  - **Groth16**: Minimal 128-byte proofs and constant-time 3-pairing verification.
  - **Plonk**: 5-round permutation argument with universal KZG polynomial commitments.
  - **STARK**: Transparent setup, execution trace low-degree extension (LDE), and post-quantum Fast Reed-Solomon Interactive Oracle Proofs of Proximity (FRI).
- **Cryptographic Gadget Suite**: In-circuit bit decomposition, range enforcement, Merkle tree inclusion verification, Poseidon hash permutations, and BabyJubJub EdDSA signature checks.
- **Automated Verifier Emission**: Generates EVM-optimized Solidity smart contracts utilizing pairing precompiles (`0x06`, `0x07`, `0x08`) and self-contained zero-allocation ANSI C99 verifiers.
- **Optional Native C Acceleration**: Transparent C extension for 256-bit Montgomery multiplication and point arithmetic, automatically falling back to pure Ruby if uncompiled.

---

## Quickstart

### 1. Constructing an Arithmetic Circuit and Proving with Groth16

```ruby
require "vellum"

# Define a cubic relation circuit: x^3 + x + 5 == y
circuit = Vellum.circuit do
  x = allocate_private(:x)
  y = allocate_public(:y)

  x2 = allocate_intermediate(:x2)
  x3 = allocate_intermediate(:x3)

  # x * x = x2
  constrain(x * x, x2)
  # x2 * x = x3
  constrain(x2 * x, x3)
  # x3 + x + 5 = y
  constrain(x3 + x + 5, y)
end

# 1. Generate Structured Reference String (SRS)
pk, vk = Vellum::Prover::Groth16.setup(circuit)

# 2. Assign witness values (private: x = 3, public: y = 35)
witness = circuit.synthesize_witness(x: 3, y: 35)

# 3. Generate zero-knowledge proof
proof = Vellum::Prover::Groth16.prove(pk, circuit, witness)

# 4. Verify proof against public inputs
is_valid = Vellum::Verifier::Groth16.verify(vk, [35], proof)
puts "Proof verification result: #{is_valid}" # => true
```

### 2. Exporting to a Solidity EVM Verifier Contract

```ruby
solidity_source = Vellum::Codegen::SolidityVerifier.generate(vk)
File.write("Verifier.sol", solidity_source)
```

The resulting contract compiles cleanly and verifies proofs on Ethereum for approx. 180,000 gas.

---

## Command Line Interface (CLI)

Vellum provides an interactive command line interface:

```bash
# Display CLI summary and available commands
./bin/vellum help

# Generate Groth16 trusted setup keys
./bin/vellum setup --circuit examples/circuit.rb --pk proving.key --vk verifying.key

# Synthesize a zero-knowledge proof
./bin/vellum prove --pk proving.key --circuit examples/circuit.rb --inputs inputs.json --out proof.json

# Verify a proof
./bin/vellum verify --vk verifying.key --proof proof.json --inputs public_inputs.json

# Launch interactive terminal UI (TUI)
./bin/vellum tui

# Run full project verification suite
./bin/vellum verify-all
```

---

## Runnable Examples

The repository includes nine end-to-end runnable examples covering fundamental and advanced zero-knowledge applications:

| Example | Description | Run Command |
| :--- | :--- | :--- |
| `01_simple_arithmetic.rb` | Cubic relation Groth16 proof with public/private inputs | `ruby examples/01_simple_arithmetic.rb` |
| `02_range_proof.rb` | Bounded bit decomposition and range constraint validation | `ruby examples/02_range_proof.rb` |
| `03_poseidon_preimage.rb` | In-circuit Poseidon hash preimage knowledge proof | `ruby examples/03_poseidon_preimage.rb` |
| `04_merkle_membership.rb` | Cryptographic Merkle tree membership proof using Poseidon | `ruby examples/04_merkle_membership.rb` |
| `05_confidential_transfer.rb` | Confidential token transfer with balance conservation checks | `ruby examples/05_confidential_transfer.rb` |
| `06_babyjubjub_signature.rb` | EdDSA signature verification over BabyJubJub curve | `ruby examples/06_babyjubjub_signature.rb` |
| `07_plonk_fibonacci.rb` | Plonkish trace generation and permutation argument check | `ruby examples/07_plonk_fibonacci.rb` |
| `08_stark_collatz.rb` | Transparent STARK on Goldilocks field with FRI low-degree test | `ruby examples/08_stark_collatz.rb` |
| `09_zk_sudoku.rb` | Zero-knowledge Sudoku puzzle validity proof | `ruby examples/09_zk_sudoku.rb` |

---

## Documentation

Comprehensive mathematical specifications and developer guides are available in the `docs/` directory:

- [System Overview](docs/architecture/system_overview.md): Abstract machine, pipeline, and intermediate representation topology.
- [Synthesis Pipeline](docs/architecture/pipeline.md): End-to-end transformation from DSL to verification targets.
- [Finite Fields](docs/math/finite_fields.md): Prime fields, Montgomery CIOS reduction, and extension towers.
- [Elliptic Curves](docs/math/elliptic_curves.md): Coordinate models, BN254, BLS12-381, BabyJubJub, and Pippenger MSM.
- [Pairing Engine](docs/math/pairings.md): Miller loops, line evaluations, Frobenius twists, and final exponentiation.
- [Polynomials & NTT](docs/math/polynomials_and_ntt.md): Fast Fourier transforms, coset shifts, and Lagrange interpolation.
- [Groth16 Protocol](docs/proof_systems/groth16.md): Protocol mathematics, SRS structures, and pairing checks.
- [Plonk Protocol](docs/proof_systems/plonk.md): 5-round interactive transcript, grand product $Z(X)$, and KZG10.
- [STARK Protocol](docs/proof_systems/stark.md): Algebraic Intermediate Representation (AIR), LDE, and FRI proximity testing.
- [Hash Functions](docs/crypto/hash_functions.md): In-circuit Poseidon, Rescue, GMiMC, and RFC 7693 BLAKE2s.
- [Verifier Codegen](docs/codegen/solidity_and_c.md): EVM precompile integration and zero-allocation C99 verifiers.
- [Performance Benchmarks](docs/benchmarks/performance_report.md): Microbenchmarks, gadget costs, and complexity scaling.

---

## Testing & Verification

Run the full unit test suite:

```bash
rake test
```

Execute all nine end-to-end examples:

```bash
for f in examples/*.rb; do ruby "$f"; done
```

---

## License

This project is licensed under the Apache License 2.0.
