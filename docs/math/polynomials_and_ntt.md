# Vellum: Polynomial Arithmetic and Number Theoretic Transforms

Polynomial manipulation over finite fields is the primary mechanism for compressing thousands of arithmetic constraints into succinct, checkable identity equations. Vellum provides an industrial-grade polynomial engine featuring fast multiplication, evaluation, division, and Number Theoretic Transforms (NTT).

---

## 1. Dense Polynomial Representations

A polynomial $P(X) \in \mathbb{F}[X]$ of degree $d$ is represented by its coefficient vector:
$$P(X) = \sum_{i=0}^d c_i X^i = c_0 + c_1 X + c_2 X^2 + \dots + c_d X^d$$
In Vellum, `Vellum::Algebra::Polynomial` maintains coefficients canonically with zero leading terms pruned.

### Operations
- **Addition & Subtraction**: Component-wise addition of coefficient vectors in $O(d)$.
- **Horner's Evaluation**: Evaluates $P(\zeta)$ in $d$ multiplications and $d$ additions:
  $$P(\zeta) = c_0 + \zeta (c_1 + \zeta (c_2 + \dots + \zeta c_d))$$
- **Euclidean Division with Remainder**: Computes unique polynomials $Q(X), R(X)$ such that:
  $$A(X) = Q(X) \cdot B(X) + R(X), \quad \deg(R) < \deg(B)$$

---

## 2. Multiplicative Subgroups and Roots of Unity

Let $\mathbb{F}_p$ be a finite field whose multiplicative group order $p - 1$ is divisible by $2^k$. A primitive $n$-th root of unity $\omega \in \mathbb{F}_p$ (where $n = 2^m \le 2^k$) generates a cyclic subgroup:
$$H = \{1, \omega, \omega^2, \dots, \omega^{n-1}\}$$
satisfying:
$$\omega^n = 1 \quad \text{and} \quad \omega^i \ne 1 \text{ for } 0 < i < n$$

### Vanishing Polynomial
The vanishing polynomial over the subgroup $H$ simplifies to a sparse binomial:
$$Z_H(X) = \prod_{i=0}^{n-1} (X - \omega^i) = X^n - 1$$
Evaluating $Z_H(\zeta)$ at an arbitrary point $\zeta \in \mathbb{F}_p$ requires only $O(\log n)$ operations using exponentiation by squaring.

---

## 3. The Number Theoretic Transform (NTT)

The Number Theoretic Transform is the finite field analogue of the Discrete Fourier Transform (DFT). Given a polynomial's coefficient vector $c = [c_0, c_1, \dots, c_{n-1}]$, the forward NTT computes evaluations at all powers of $\omega$:
$$\text{NTT}(c)_j = P(\omega^j) = \sum_{k=0}^{n-1} c_k \omega^{j \cdot k}, \quad 0 \le j < n$$
The inverse NTT recovers coefficients from evaluations:
$$\text{iNTT}(e)_k = c_k = \frac{1}{n} \sum_{j=0}^{n-1} e_j \omega^{-j \cdot k}, \quad 0 \le k < n$$

### Radix-2 Cooley-Tukey Butterfly
Vellum implements in-place decimation-in-time Cooley-Tukey NTT:
```
Algorithm: Radix-2 Cooley-Tukey NTT
Input: Array a of size n = 2^m, root of unity omega
Output: In-place transform of a

1. Bit-reverse the elements of array a
2. For len = 2, 4, 8, ..., n:
       w_step = omega^(n / len)
       For i = 0 to n - 1 step len:
           w = 1
           For j = 0 to (len / 2) - 1:
               u = a[i + j]
               v = a[i + j + len/2] * w
               a[i + j] = u + v
               a[i + j + len/2] = u - v
               w = w * w_step
```
Time complexity: $O(n \log n)$ field operations, compared to $O(n^2)$ for naive evaluation.

---

## 4. Coset NTT for Quotient Polynomials

When computing quotient polynomials in proof systems:
$$H(X) = \frac{A(X) \cdot B(X) - C(X)}{X^n - 1}$$
evaluating the numerator on the subgroup $H$ yields zeros for all points, causing an undefined division $0 / 0$.

Vellum resolves this by shifting evaluations to an affine coset $g \cdot H = \{g \cdot \omega^0, g \cdot \omega^1, \dots, g \cdot \omega^{n-1}\}$ where $g$ is a generator of $\mathbb{F}_p^\times$ outside $H$:
1. Scale coefficients by powers of the coset shift: $c_k' = c_k \cdot g^k$.
2. Perform standard NTT on $c'$: $e_j = \text{NTT}(c')_j = P(g \cdot \omega^j)$.
3. Evaluate the quotient pointwise on the coset without singularities:
   $$H(g \cdot \omega^j) = \frac{A(g \cdot \omega^j) B(g \cdot \omega^j) - C(g \cdot \omega^j)}{(g \cdot \omega^j)^n - 1}$$
4. Apply inverse NTT and deshift coefficients: $h_k = \text{iNTT}(H)_k \cdot g^{-k}$.

---

## 5. Lagrange Basis Interpolation

The Lagrange basis polynomial $L_i(X)$ corresponding to subgroup element $\omega^i$ is defined as:
$$L_i(X) = \prod_{j=0, j \ne i}^{n-1} \frac{X - \omega^j}{\omega^i - \omega^j} = \frac{\omega^i}{n} \cdot \frac{X^n - 1}{X - \omega^i}$$
For any set of values $y_0, y_1, \dots, y_{n-1}$, the unique interpolating polynomial of degree $< n$ is:
$$P(X) = \sum_{i=0}^{n-1} y_i L_i(X)$$
Using barycentric weights and the vanishing polynomial formula, evaluating $P(\zeta)$ at an arbitrary point $\zeta \notin H$ takes $O(n)$ operations without reconstructing the full polynomial coefficients.
