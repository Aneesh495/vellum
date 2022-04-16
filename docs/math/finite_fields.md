# Vellum: Finite Field Mathematics and Extension Towers

Finite fields form the fundamental algebraic substrate of verifiable computation. Vellum implements an arbitrary-precision algebraic core featuring prime fields, field extensions, and optimized reduction algorithms.

## Prime Fields ($\mathbb{F}_p$)

A prime field $\mathbb{F}_p$ is a Galois field with a prime number of elements $p$. Elements are integers modulo $p$, supporting associative, commutative, and distributive addition, subtraction, multiplication, and multiplicative inversion:

$$\mathbb{F}_p = \{0, 1, \dots, p - 1\}$$

In Vellum, `Vellum::Algebra::PrimeField` manages field parameters, and `Vellum::Algebra::FieldElement` encapsulates elements with canonical equivalence relations.

### Fast Inversion and Division
Multiplicative inverses are computed via the Extended Euclidean Algorithm, computing coefficients $x, y$ such that:
$$a \cdot x + p \cdot y = \gcd(a, p) = 1 \implies a^{-1} \equiv x \pmod p$$
Alternatively, Fermat's Little Theorem provides $a^{-1} \equiv a^{p - 2} \pmod p$.

### Tonelli-Shanks Square Roots
Quadratic residues $a \in \mathbb{F}_p$ (satisfying the Legendre symbol $a^{(p-1)/2} \equiv 1 \pmod p$) admit square roots $r^2 \equiv a \pmod p$. Vellum implements the Tonelli-Shanks algorithm:
1. Decompose $p - 1 = Q \cdot 2^S$ where $Q$ is odd.
2. Select a non-residue $z$.
3. Compute initial approximations and iteratively eliminate factors of 2 from the order of the error term.

---

## Montgomery Reduction and CIOS

Standard integer division modulo $p$ is computationally expensive. Montgomery multiplication transforms field elements into Montgomery form:
$$\tilde{a} = a \cdot R \pmod p$$
where $R = 2^k > p$ with $\gcd(R, p) = 1$. Multiplication in Montgomery form computes:
$$\text{MontMul}(\tilde{a}, \tilde{b}) = \frac{\tilde{a} \cdot \tilde{b} + m \cdot p}{R} \equiv a \cdot b \cdot R \pmod p$$
where $m = ((\tilde{a} \cdot \tilde{b} \bmod R) \cdot p') \bmod R$, and $p' \equiv -p^{-1} \pmod R$.

### Coarsely Integrated Operand Scanning (CIOS)
For multi-precision integers on 64-bit architectures, Vellum implements CIOS Montgomery multiplication:
```
for i from 0 to N-1:
    C = 0
    for j from 0 to N-1:
        (C, t[j]) = t[j] + a[j] * b[i] + C
    (t[N+1], t[N]) = t[N] + C

    m = t[0] * p_prime mod 2^64
    C = 0
    for j from 0 to N-1:
        (C, t[j]) = t[j] + m * p[j] + C
    (t[N+1], t[N]) = t[N] + C
    t = t >> 64
```
This avoids allocating large intermediate product buffers and operates in $O(N^2)$ limb operations.

---

## Extension Field Towers ($\mathbb{F}_{p^2} \to \mathbb{F}_{p^6} \to \mathbb{F}_{p^{12}}$)

Bilinear pairings require evaluating polynomials over target extension fields $\mathbb{F}_{p^k}$, where $k$ is the embedding degree (for BN254 and BLS12-381, $k = 12$). Directly computing over $\mathbb{F}_{p^{12}}$ as a degree-12 polynomial is intractable. Vellum constructs an optimal tower of extensions:

```
                  F_{p^12} = F_{p^6}[w] / (w^2 - v)
                             |
                  F_{p^6}  = F_{p^2}[v] / (v^3 - xi)
                             |
                  F_{p^2}  = F_p[u]     / (u^2 - beta)
                             |
                            F_p
```

### Quadratic Extension ($\mathbb{F}_{p^2}$)
Elements are represented as $c_0 + c_1 u$ where $c_0, c_1 \in \mathbb{F}_p$ and $u^2 = \beta$:
$$(a_0 + a_1 u)(b_0 + b_1 u) = (a_0 b_0 + a_1 b_1 \beta) + (a_0 b_1 + a_1 b_0) u$$
For BN254, $\beta = -1$, yielding $u^2 + 1 = 0$.

Multiplicative inversion uses complex conjugation:
$$(a_0 + a_1 u)^{-1} = \frac{a_0 - a_1 u}{a_0^2 - \beta a_1^2}$$

### Sextic Extension ($\mathbb{F}_{p^6}$)
Constructed as a cubic extension over $\mathbb{F}_{p^2}$ modulo $v^3 - \xi$, where $\xi = u + 9$ for BN254. Elements are represented as $c_0 + c_1 v + c_2 v^2$ with $c_i \in \mathbb{F}_{p^2}$.

### Dodecic Extension ($\mathbb{F}_{p^{12}}$)
Constructed as a quadratic extension over $\mathbb{F}_{p^6}$ modulo $w^2 - v$. Elements are represented as $c_0 + c_1 w$ with $c_i \in \mathbb{F}_{p^6}$.

Multiplication over $\mathbb{F}_{p^{12}}$ uses Karatsuba reduction:
$$(a_0 + a_1 w)(b_0 + b_1 w) = (a_0 b_0 + a_1 b_1 v) + ((a_0 + a_1)(b_0 + b_1) - a_0 b_0 - a_1 b_1) w$$
This reduces 4 multiplications in $\mathbb{F}_{p^6}$ to 3.

---

## The Goldilocks Field ($\mathbb{F}_{2^{64} - 2^{32} + 1}$)

For STARK proof systems and recursive FRI verifiers, Vellum implements the Goldilocks prime field:
$$p = 2^{64} - 2^{32} + 1$$

### Reduction Properties
The Goldilocks modulus has the special property:
$$2^{64} \equiv 2^{32} - 1 \pmod p$$
$$2^{96} \equiv -1 \pmod p$$
Integers up to 128 bits resulting from product accumulations can be reduced into the canonical 64-bit field using only 32-bit shifts and additions, avoiding division entirely:
```
Given x = x_hi * 2^64 + x_lo:
x = x_lo + x_hi * (2^32 - 1)
```
This enables high-throughput trace generation and fast Number Theoretic Transforms (NTT) for STARK verification.
