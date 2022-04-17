# Vellum: Elliptic Curves and Coordinate Systems

Elliptic curves provide the additive abelian groups $(G_1, G_2, G_T)$ that underpin pairing-based zero-knowledge arguments and cryptographic signatures. Vellum implements short Weierstrass curves, twisted Edwards curves, Jacobian projective coordinate models, and multi-scalar multiplication (MSM) algorithms.

---

## 1. Short Weierstrass Curves

A short Weierstrass elliptic curve over a prime field $\mathbb{F}_p$ is the set of points $(x, y) \in \mathbb{F}_p^2$ satisfying:
$$y^2 = x^3 + a x + b$$
together with a point at infinity $\mathcal{O}$ acting as the group identity element.

### Affine Addition Law
For points $P = (x_1, y_1)$ and $Q = (x_2, y_2)$ with $P \ne \pm Q$:
$$\lambda = \frac{y_2 - y_1}{x_2 - x_1}, \quad x_3 = \lambda^2 - x_1 - x_2, \quad y_3 = \lambda (x_1 - x_3) - y_1$$

### Affine Doubling Law ($P = Q$)
$$\lambda = \frac{3 x_1^2 + a}{2 y_1}, \quad x_3 = \lambda^2 - 2 x_1, \quad y_3 = \lambda (x_1 - x_3) - y_1$$

Affine formulas require a modular inversion in $\mathbb{F}_p$ per group operation, which dominates execution time.

---

## 2. Jacobian Projective Coordinates

To eliminate modular inversions during scalar multiplication, Vellum utilizes Jacobian coordinates $(X:Y:Z)$ representing the affine point:
$$(x, y) = \left( \frac{X}{Z^2}, \frac{Y}{Z^3} \right)$$
The curve equation transforms into:
$$Y^2 = X^3 + a X Z^4 + b Z^6$$
The point at infinity is uniquely represented by $(1 : 1 : 0)$.

### Jacobian Doubling ($a = 0$, as in BN254 and BLS12-381)
Given $P = (X_1 : Y_1 : Z_1)$, compute $2P = (X_3 : Y_3 : Z_3)$:
1. $S = 4 X_1 Y_1^2$
2. $M = 3 X_1^2$
3. $X_3 = M^2 - 2 S$
4. $Y_3 = M (S - X_3) - 8 Y_1^4$
5. $Z_3 = 2 Y_1 Z_1$

Cost: 3 field multiplications, 4 field squarings, 0 field inversions ($3M + 4S$).

### Mixed Addition (Jacobian + Affine)
When adding an affine point $(x_2, y_2, 1)$ to a Jacobian point $(X_1 : Y_1 : Z_1)$:
1. $Z_1^2 = Z_1 \cdot Z_1$
2. $U_2 = x_2 \cdot Z_1^2$
3. $S_2 = y_2 \cdot Z_1 \cdot Z_1^2$
4. $H = U_2 - X_1$
5. $R = S_2 - Y_1$
6. $X_3 = R^2 - H^3 - 2 X_1 H^2$
7. $Y_3 = R (X_1 H^2 - X_3) - Y_1 H^3$
8. $Z_3 = Z_1 \cdot H$

Cost: 7 field multiplications, 4 field squarings ($7M + 4S$).

---

## 3. Supported Curve Families

### BN254 (alt_bn128)
BN254 is a Barreto-Naehrig pairing-friendly curve with embedding degree $k = 12$:
- Modulus: $p = 21888242871839275222246405745257275088696311157297823662689037894645226208583$
- Order: $r = 21888242871839275222246405745257275088548364400416034343698204186575808495617$
- $G_1$ curve: $y^2 = x^3 + 3$ over $\mathbb{F}_p$
- $G_2$ curve: $y^2 = x^3 + 3 / (u + 9)$ over $\mathbb{F}_{p^2}$ (via sextic D-type twist)

BN254 has native EVM precompile support on Ethereum (`ecAdd`, `ecMul`, `ecPairing`).

### BLS12-381
BLS12-381 is a Barreto-Lynn-Scott pairing-friendly curve targeted at 128-bit security:
- Modulus: $p = \text{0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab}$
- Order: $r = \text{0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001}$
- $G_1$ curve: $y^2 = x^3 + 4$ over $\mathbb{F}_p$
- $G_2$ curve: $y^2 = x^3 + 4(u + 1)$ over $\mathbb{F}_{p^2}$ (via sextic M-type twist)

### BabyJubJub
BabyJubJub is a Twisted Edwards curve defined over the scalar field $\mathbb{F}_r$ of BN254:
$$a x^2 + y^2 = 1 + d x^2 y^2$$
where $a = 168700$ and $d = 168696$.
Because its base field matches the scalar field of BN254, elliptic curve operations on BabyJubJub can be verified inside BN254 arithmetic circuits with minimal constraint overhead (approx. 3-4 constraints per group operation), making it the optimal choice for SNARK-friendly digital signatures (EdDSA) and confidential transactions.

---

## 4. Multi-Scalar Multiplication (MSM)

In zero-knowledge provers, the dominant computational bottleneck is computing multi-scalar linear combinations:
$$Q = \sum_{i=1}^N s_i \cdot P_i$$
where $s_i \in \mathbb{F}_r$ and $P_i \in G_1$ (or $G_2$).

### Pippenger's Bucket Method
Instead of computing $N$ independent scalar multiplications taking $O(N \cdot \lambda)$ additions, Pippenger's algorithm segments the $\lambda$-bit scalars into $w$-bit windows:
1. Divide scalar bits into $K = \lceil \lambda / w \rceil$ windows of $w$ bits each.
2. For each window $k$, sort points into $2^w - 1$ buckets according to their window value $v_{i,k}$:
   $$B_j = \sum_{i : v_{i,k} = j} P_i$$
3. Compute the window sum via partial prefix sums without scalar multiplications:
   $$W_k = \sum_{j=1}^{2^w - 1} j \cdot B_j = \sum_{j=1}^{2^w - 1} \left( \sum_{m=j}^{2^w - 1} B_m \right)$$
4. Combine window results using Horner's rule:
   $$Q = \sum_{k=0}^{K-1} 2^{w \cdot k} W_k$$

Complexity reduces from $O(N \cdot \lambda)$ to $O\left( \frac{N \lambda}{\log N} \right)$, yielding orders of magnitude speedups for large witness vectors.
