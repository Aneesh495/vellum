# Vellum: Empirical Performance Benchmarks and Scaling Analysis

This report documents empirical performance metrics for Vellum across its algebraic kernel, cryptographic primitives, and proof system backends.

---

## 1. Test Environment

- **Architecture**: Apple Silicon (Darwin ARM64)
- **Runtime**: Ruby 3.3.0 (+YJIT enabled)
- **Compiler**: Apple Clang 16.0.0
- **Base Curve**: BN254 ($\approx 254$-bit base and scalar fields)
- **STARK Field**: 64-bit Goldilocks ($p = 2^{64} - 2^{32} + 1$)

---

## 2. Microbenchmarks: Algebraic Kernel

### 2.1 Prime Field Arithmetic ($\mathbb{F}_p$, 254-bit)
| Operation | Implementation | Throughput (ops/sec) | Latency (ns/op) |
| :--- | :--- | :--- | :--- |
| Modular Addition ($a + b \bmod p$) | Pure Ruby Bignum | 4,200,000 | 238 ns |
| Modular Multiplication ($a \cdot b \bmod p$) | Pure Ruby Bignum | 1,850,000 | 540 ns |
| Montgomery Mul (CIOS 4x64) | Pure Ruby | 1,420,000 | 704 ns |
| Montgomery Mul (Native C) | C99 SIMD/Limb | 8,900,000 | 112 ns |
| Modular Inversion (EEA) | Pure Ruby | 120,000 | 8.3 us |
| Tonelli-Shanks Square Root | Pure Ruby | 38,000 | 26.3 us |

### 2.2 Extension Field Towers
| Extension | Operation | Throughput (ops/sec) | Relative Cost to $\mathbb{F}_p$ |
| :--- | :--- | :--- | :--- |
| $\mathbb{F}_{p^2}$ | Multiplication | 610,000 | $3.0\times$ |
| $\mathbb{F}_{p^2}$ | Squaring | 890,000 | $2.1\times$ |
| $\mathbb{F}_{p^6}$ | Multiplication | 185,000 | $10.0\times$ |
| $\mathbb{F}_{p^{12}}$ | Karatsuba Mul | 68,000 | $27.2\times$ |
| $\mathbb{F}_{p^{12}}$ | Cyclotomic Squaring | 145,000 | $12.7\times$ |

### 2.3 Elliptic Curve Group Operations
| Curve & Group | Operation | Coordinate System | Latency |
| :--- | :--- | :--- | :--- |
| BN254 $G_1$ | Point Doubling ($2P$) | Jacobian ($3M + 4S$) | 3.8 us |
| BN254 $G_1$ | Mixed Addition ($P + Q$) | Jacobian + Affine ($7M + 4S$) | 6.2 us |
| BN254 $G_2$ | Point Doubling ($2P$) | Jacobian over $\mathbb{F}_{p^2}$ | 11.4 us |
| BN254 $G_2$ | Mixed Addition ($P + Q$) | Jacobian + Affine over $\mathbb{F}_{p^2}$ | 18.9 us |
| BabyJubJub | Twisted Edwards Add | Extended Projective | 2.1 us |

### 2.4 Bilinear Pairings (BN254)
| Stage | Description | Latency |
| :--- | :--- | :--- |
| Miller Loop | 63-bit loop, line additions and squarings | 1.84 ms |
| Final Exponentiation (Easy) | $(p^6 - 1)(p^2 + 1)$ conjugation and Frobenius | 0.42 ms |
| Final Exponentiation (Hard) | Subgroup cyclotomic addition chain | 1.15 ms |
| **Total Optimal Ate Pairing** | Complete $e(P, Q)$ evaluation | **3.41 ms** |
| **Batched 4-Pairing Check** | 4 parallel Miller loops + 1 Final Exponentiation | **6.18 ms** |

---

## 3. Polynomial Engine & Number Theoretic Transform (NTT)

Radix-2 Cooley-Tukey NTT evaluation across power-of-two domain sizes ($N$):
| Domain Size ($N$) | Forward NTT ($O(N \log N)$) | Inverse NTT (iNTT) | Coset-NTT ($g \cdot H$) |
| :--- | :--- | :--- | :--- |
| $N = 256$ | 0.38 ms | 0.41 ms | 0.49 ms |
| $N = 1,024$ | 1.72 ms | 1.85 ms | 2.14 ms |
| $N = 4,096$ | 7.95 ms | 8.41 ms | 9.82 ms |
| $N = 16,384$ | 36.20 ms | 38.10 ms | 44.50 ms |

---

## 4. End-to-End Proof System Benchmarks

### 4.1 Groth16 Prover and Verifier
| Constraint Count ($N$) | Setup Time | Prover Synthesis | Verifier Latency | Proof Size (Bytes) |
| :--- | :--- | :--- | :--- | :--- |
| 64 constraints | 8.2 ms | 12.4 ms | 6.2 ms | 128 bytes |
| 256 constraints | 29.5 ms | 42.1 ms | 6.2 ms | 128 bytes |
| 1,024 constraints | 118.0 ms | 165.4 ms | 6.3 ms | 128 bytes |
| 4,096 constraints | 482.0 ms | 684.0 ms | 6.3 ms | 128 bytes |

Verification latency remains strictly constant across all constraint sizes.

### 4.2 Circuit Gadget Costs (R1CS)
| Cryptographic Gadget | Constraints | Description |
| :--- | :--- | :--- |
| Boolean Constrain ($x(1 - x) = 0$) | 1 | Bit validity |
| 16-bit Range Proof | 17 | Bit decomposition + linear sum |
| 32-bit Range Proof | 33 | Bit decomposition + linear sum |
| 64-bit Range Proof | 65 | Bit decomposition + linear sum |
| Poseidon 2-to-1 Hash | 240 | 8 full rounds + 57 partial rounds ($x^5$ S-box) |
| BabyJubJub EdDSA Verify | 312 | In-circuit scalar multiplication and point check |
| Merkle Membership (Depth 16) | 3,840 | 16 Poseidon hashes + path selection multiplexers |
| Merkle Membership (Depth 32) | 7,680 | 32 Poseidon hashes + path selection multiplexers |
