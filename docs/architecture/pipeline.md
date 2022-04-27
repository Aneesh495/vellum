# Vellum: End-to-End Synthesis Pipeline

This document details the lifecycle of a verifiable computation in Vellum, from domain-specific circuit declaration to proof verification and smart contract emission.

```
+-------------------------------------------------------------------------+
| Phase 1: Circuit Definition                                             |
|   circuit = Vellum.circuit do                                           |
|     x = private_input(:x)                                               |
|     y = public_input(:y)                                                |
|     assert_equal(x * x, y)                                              |
|   end                                                                   |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 2: Constraint Optimization & Normalization                        |
|   - Dead-code elimination: Prune unused intermediate wires              |
|   - Linear substitution: Collapse constant additions and scalings      |
|   - Matrix canonicalization: Map variables to column index vector w     |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 3: Rank-1 Constraint System (R1CS) Representation                 |
|   Matrices A, B, C such that (A * w) o (B * w) = C * w                  |
|   w = [1, public_inputs..., private_witness...]                         |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 4: QAP Arithmetization (Lagrange Interpolation)                   |
|   - Evaluation domain: Omega = {omega^0, omega^1, ..., omega^{m-1}}     |
|   - Vanishing polynomial: t(x) = x^m - 1                                |
|   - Polynomials: A_i(x), B_i(x), C_i(x)                                 |
|   - Target relation: p(x) = A(x)*B(x) - C(x) = h(x)*t(x)                |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 5: Cryptographic Proving Engine (Groth16 / Plonk / STARK)         |
|   - Multiscalar Multiplications (MSM) over G1 and G2                    |
|   - Blinding factor generation (r, s in Fr)                             |
|   - Output Proof: pi = { A in G1, B in G2, C in G1 }                    |
+-------------------------------------------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
| Phase 6: Verification & Code Generation                                 |
|   - Native Ruby: e(A, B) = e(alpha, beta) + e(IC, gamma) + e(C, delta)  |
|   - Solidity Contract: Generated Verifier.sol with alt_bn128 precompile |
|   - C99 Header: Zero-allocation standalone verifier                     |
+-------------------------------------------------------------------------+
```

## Detailed Execution Phases

### Phase 1: Declarative Circuit Construction
Circuits are expressed in Ruby using the `Vellum::DSL::Builder` interface. During this phase, variables are instantiated as symbolic entities (`Variable` instances) representing wires:
- Public inputs: Variables whose values are known to both the prover and verifier.
- Private inputs: Secret witness variables known only to the prover.
- Intermediate variables: Derived signals produced by arithmetic operations.

Linear combinations of variables are tracked symbolically using `LinearCombination` instances, which map variable identifiers to field coefficients.

### Phase 2: Constraint Optimization
Before constructing the full constraint matrices, the `R1CSOptimizer` performs analytical passes:
1. **Constant Folding**: Evaluates constant linear terms at compile time.
2. **Linear Substitution**: Replaces intermediate variables defined by affine relationships (e.g., $z = 2x + 3y$) directly into downstream constraints, eliminating unnecessary wires and constraints.
3. **Dead Variable Elimination**: Prunes wires that do not contribute to any active constraint.

### Phase 3: Rank-1 Constraint Matrix Generation
The circuit is flattened into three sparse matrices $A$, $B$, and $C$, where each row represents a constraint of the form:
$$(\sum_{i=0}^{n-1} A_{j,i} w_i) \cdot (\sum_{i=0}^{n-1} B_{j,i} w_i) = \sum_{i=0}^{n-1} C_{j,i} w_i$$
The full assignment vector $w$ is structured as:
$$w = [1, \text{pub}_1, \dots, \text{pub}_l, \text{priv}_1, \dots, \text{priv}_k]^T$$
where $w_0 = 1$ is the canonical constant wire.

### Phase 4: Quadratic Arithmetic Program (QAP) Transformation
To enable succinct evaluation, the discrete constraints are encoded as univariate polynomials over a finite field:
1. A multiplicative subgroup $H = \{1, \omega, \omega^2, \dots, \omega^{m-1}\}$ of order $m$ is selected such that $m \ge \text{num\_constraints}$, where $m$ is a power of 2.
2. Lagrange basis polynomials $L_j(x)$ are constructed such that $L_j(\omega^k) = \delta_{j,k}$.
3. Matrix polynomials are synthesized:
   $$A_i(x) = \sum_{j=0}^{m-1} A_{j,i} L_j(x), \quad B_i(x) = \sum_{j=0}^{m-1} B_{j,i} L_j(x), \quad C_i(x) = \sum_{j=0}^{m-1} C_{j,i} L_j(x)$$
4. Given a valid witness vector $w$, the polynomial:
   $$p(x) = \left( \sum_{i=0}^{n-1} w_i A_i(x) \right) \left( \sum_{i=0}^{n-1} w_i B_i(x) \right) - \left( \sum_{i=0}^{n-1} w_i C_i(x) \right)$$
   vanishes on every element of $H$. Therefore, $p(x)$ is divisible by the vanishing polynomial $t(x) = x^m - 1$, yielding the quotient polynomial $h(x) = p(x) / t(x)$.

### Phase 5: Zero-Knowledge Proof Synthesis (Groth16)
Using the Structured Reference String (SRS) containing secret evaluation points $\tau, \alpha, \beta, \gamma, \delta$:
1. Random blinding factors $r, s \in \mathbb{F}_r$ are drawn to guarantee perfect zero knowledge.
2. The prover evaluates multiscalar multiplications (MSMs) in $G_1$ and $G_2$:
   $$A = \alpha + \sum_{i=0}^{n-1} w_i [A_i(\tau)]_1 + r [\delta]_1$$
   $$B = \beta + \sum_{i=0}^{n-1} w_i [B_i(\tau)]_2 + s [\delta]_2$$
   $$C = \sum_{i=l+1}^{n-1} w_i \left[ \frac{\beta A_i(\tau) + \alpha B_i(\tau) + C_i(\tau)}{\delta} \right]_1 + \left[ \frac{h(\tau) t(\tau)}{\delta} \right]_1 + s A + r B - r s [\delta]_1$$
3. The resulting proof consists of only three group elements: $(A \in G_1, B \in G_2, C \in G_1)$.

### Phase 6: Verification and Automated Code Generation
Verification evaluates a single pairing check:
$$e(A, B) = e(\alpha, \beta) \cdot e\left(\sum_{i=0}^{l} w_i [IC_i]_1, \gamma\right) \cdot e(C, \delta)$$
Vellum automates this through multiple targets:
- **In-Memory Verification**: Pure Ruby pairing engine evaluating Miller loops and final exponentiations.
- **Solidity Verifier**: Generates ready-to-deploy Solidity code utilizing EVM precompiles (`ecAdd` at `0x06`, `ecMul` at `0x07`, and `ecPairing` at `0x08`).
- **C99 Verifier**: Generates ANSI C verification routines for native platforms.
