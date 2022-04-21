# Vellum: The Plonk Proof System

Plonk (Permutations over Lagrange-bases for O(n) SNARKs) is a universal, updatable zero-knowledge proof system. Unlike Groth16, which requires a circuit-specific trusted setup, Plonk uses a single universal Structured Reference String (SRS) for all circuits up to a given size bound.

---

## 1. Plonkish Arithmetization

A computation in Plonk is represented as an execution trace matrix of $n$ rows and 3 wire columns:
- $a_i$: Left wire assignment for row $i$
- $b_i$: Right wire assignment for row $i$
- $c_i$: Output wire assignment for row $i$

### Gate Constraints
Each row $i \in \{0, \dots, n-1\}$ satisfies the universal gate equation:
$$q_{L,i} \cdot a_i + q_{R,i} \cdot b_i + q_{O,i} \cdot c_i + q_{M,i} \cdot (a_i \cdot b_i) + q_{C,i} = 0$$
where $q_L, q_R, q_O, q_M, q_C$ are fixed selector polynomials:
- **Addition Gate** ($a_i + b_i = c_i$): $q_L = 1, q_R = 1, q_O = -1, q_M = 0, q_C = 0$
- **Multiplication Gate** ($a_i \cdot b_i = c_i$): $q_L = 0, q_R = 0, q_O = -1, q_M = 1, q_C = 0$
- **Constant Gate** ($c_i = K$): $q_L = 0, q_R = 0, q_O = -1, q_M = 0, q_C = K$

---

## 2. Copy Constraints and the Permutation Argument

To ensure wires in different gates correctly share values (e.g., the output of gate 1 equals the left input of gate 5), Plonk encodes copy relations as a permutation $\sigma$ over the $3n$ wire slots.

### Coset Domain Separation
The three columns are mapped to disjoint cosets of the roots of unity $H = \{1, \omega, \dots, \omega^{n-1}\}$:
- Column $a$: evaluated on $H$
- Column $b$: evaluated on $k_1 \cdot H$
- Column $c$: evaluated on $k_2 \cdot H$

where $k_1, k_2$ are quadratic and cubic non-residues in $\mathbb{F}_p$.

### The Grand Product Polynomial $Z(X)$
Using Fiat-Shamir random challenges $\beta, \gamma \in \mathbb{F}_p$, the prover constructs the accumulator polynomial $Z(X)$ satisfying:
$$Z(1) = 1$$
$$Z(\omega X) = Z(X) \cdot \frac{(a(X) + \beta X + \gamma)(b(X) + \beta k_1 X + \gamma)(c(X) + \beta k_2 X + \gamma)}{(a(X) + \beta \sigma_1(X) + \gamma)(b(X) + \beta \sigma_2(X) + \gamma)(c(X) + \beta \sigma_3(X) + \gamma)}$$
If and only if the copy constraints are preserved, the product over all roots of unity wraps around to $Z(\omega^{n-1} \cdot \omega) = Z(1) = 1$.

---

## 3. The 5-Round Protocol Transcript

Vellum compiles the interactive Plonk protocol into a non-interactive proof via the Fiat-Shamir heuristic using algebraic hashing:

```
Round 1: Prover commits to wire polynomials [a(X)], [b(X)], [c(X)]
         Fiat-Shamir challenge -> beta, gamma

Round 2: Prover constructs and commits to permutation accumulator [Z(X)]
         Fiat-Shamir challenge -> alpha

Round 3: Prover constructs quotient polynomial t(X) split into degree-n chunks:
         t(X) = t_lo(X) + X^n * t_mid(X) + X^(2n) * t_hi(X)
         Prover commits to [t_lo(X)], [t_mid(X)], [t_hi(X)]
         Fiat-Shamir challenge -> zeta (evaluation challenge)

Round 4: Prover computes openings at zeta and zeta * omega:
         a_bar = a(zeta), b_bar = b(zeta), c_bar = c(zeta)
         s1_bar = sigma_1(zeta), s2_bar = sigma_2(zeta)
         z_omega_bar = Z(zeta * omega)
         Fiat-Shamir challenge -> v (linearization challenge)

Round 5: Prover evaluates linearization polynomial r(X) and computes KZG opening proofs:
         W_zeta(X) and W_{zeta * omega}(X)
```

---

## 4. KZG Polynomial Commitments

Plonk relies on the Kate-Zaverucha-Goldberg (KZG10) commitment scheme over a pairing-friendly elliptic curve:
- **Commitment**: Given polynomial $P(X) = \sum c_i X^i$, the commitment is $[P(\tau)]_1 = \sum c_i [\tau^i]_1 \in G_1$.
- **Evaluation Proof**: To prove $P(\zeta) = y$, compute the quotient:
  $$Q(X) = \frac{P(X) - y}{X - \zeta}$$
  The evaluation proof is $\pi = [Q(\tau)]_1$.
- **Pairing Verification**:
  $$e(\pi, [\tau]_2 - \zeta [1]_2) = e([P(\tau)]_1 - y [1]_1, [1]_2)$$
  This verifies that $P(X) - y$ is divisible by $X - \zeta$ with a single pairing equality check.
