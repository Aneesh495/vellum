# Vellum: Bilinear Pairings, Miller Loops, and Final Exponentiation

Bilinear pairings provide the non-linear algebraic verification bridge that enables succinct zero-knowledge arguments to verify relationships between hidden commitments in constant time.

---

## 1. Mathematical Foundations

A pairing is a non-degenerate, bilinear map from two elliptic curve groups $G_1$ and $G_2$ of prime order $r$ to a multiplicative target group $G_T \subset \mathbb{F}_{p^{12}}^\times$:
$$e: G_1 \times G_2 \to G_T$$

### Core Properties
1. **Bilinearity**: For all $P \in G_1, Q \in G_2$ and $a, b \in \mathbb{F}_r$:
   $$e(a P, b Q) = e(P, Q)^{a \cdot b} = e(b P, a Q)$$
2. **Non-Degeneracy**: If $P \ne \mathcal{O}$ and $Q \ne \mathcal{O}$, then:
   $$e(P, Q) \ne 1$$
3. **Efficient Computability**: Computable in polynomial time via Miller's algorithm.

---

## 2. The Optimal Ate Pairing

The Tate pairing evaluates divisors over the full curve. The Ate pairing optimizes this by reducing the Miller loop length from $r$ (the 254-bit group order) to the trace of Frobenius $t - 1$ (approx. 63 bits for BN254).

The optimal Ate pairing on BN254 is computed as:
$$e_{\text{opt}}(P, Q) = \left( f_{6u+2, Q}(P) \cdot l_{Q_1, -Q_2}(P) \cdot l_{Q_1 + (6u+2)Q, Q_1}(P) \right)^{\frac{p^{12} - 1}{r}}$$
where $u = 4965661367192848881$ is the BN parameter, and $Q_1 = \pi_p(Q), Q_2 = \pi_p^2(Q)$ are images under the $p$-power Frobenius endomorphism.

---

## 3. The Miller Loop

The Miller loop computes rational functions $f_{m, Q}$ whose divisor is:
$$\text{div}(f_{m, Q}) = m [Q] - [m Q] - (m - 1) [\mathcal{O}]$$
Evaluating $f_{m, Q}$ at point $P$ proceeds via double-and-add over the binary expansion of $m$:

```
Algorithm: Miller Loop for BN254
Input: P in G1, Q in G2, loop scalar T = 6u + 2
Output: f in F_{p^12}

1. Let bits = binary_decomposition(|T|)
2. T_curr = Q
3. f = 1
4. For bit in bits[1..-1]:
       f = f^2 * line_double(T_curr, P)
       T_curr = 2 * T_curr
       If bit == 1:
           f = f * line_add(T_curr, Q, P)
           T_curr = T_curr + Q
5. Return f
```

### Line Evaluations
For an elliptic point $P = (x_P, y_P)$ and projective twist point $T = (X_T, Y_T, Z_T)$, the line function evaluates:
$$l_{T, Q}(P) = \lambda (x_P - x_T) - (y_P - y_T)$$
Vellum optimizes line evaluation by mapping intermediate twist coordinates directly into $\mathbb{F}_{p^{12}}$ sparse elements, reducing 12-dimensional polynomial multiplications to sparse additions and $3 \times 3$ multiplications over $\mathbb{F}_{p^2}$.

---

## 4. Final Exponentiation

The value $f$ returned by the Miller loop is not yet unique up to group isomorphism. It must be raised to the power:
$$d = \frac{p^{12} - 1}{r}$$
This operation is partitioned into an **easy part** and a **hard part**:

### The Easy Part
Factorize the exponent:
$$\frac{p^{12} - 1}{r} = \left( \frac{p^{12} - 1}{p^6 + 1} \right) \cdot \left( \frac{p^6 + 1}{p^2 - 1} \right) \cdot \left( \frac{p^2 - 1}{r} \right) = (p^6 - 1) \cdot (p^2 + 1) \cdot \frac{p^4 - p^2 + 1}{r}$$

1. **First step**: $f_1 = f^{p^6 - 1} = f^{p^6} / f$. Since $p^6$ acts as complex conjugation in $\mathbb{F}_{p^{12}}$, this requires only one inversion and sign negation.
2. **Second step**: $f_2 = f_1^{p^2 + 1} = f_1^{p^2} \cdot f_1$. Computing $f^{p^2}$ uses the Frobenius map $\pi_p^2$ over $\mathbb{F}_{p^2}$.

### The Hard Part
The remaining factor $\frac{p^4 - p^2 + 1}{r}$ is evaluated using a dedicated addition chain in terms of the BN parameter $u$:
$$e_p(u) = d_{\text{hard}}$$
Vellum evaluates this using cyclotomic squaring in the subgroup $\mathbb{G}_\Phi \subset \mathbb{F}_{p^{12}}$, where squarings cost only 8 field multiplications rather than 18.

---

## 5. Multi-Pairing Product Check

Groth16 verification requires evaluating:
$$e(A, B) \cdot e(-IC, \gamma) \cdot e(-C, \delta) \stackrel{?}{=} e(\alpha, \beta)$$
Instead of computing four independent pairings (each requiring a full final exponentiation), Vellum performs **batched multi-pairing**:
1. Run all four Miller loops in parallel:
   $$F = f_{A, B} \cdot f_{-IC, \gamma} \cdot f_{-C, \delta} \cdot f_{-\alpha, \beta}$$
2. Compute **one single final exponentiation** on the product $F$:
   $$\text{FinalExp}(F) \stackrel{?}{=} 1 \in G_T$$
This reduces verification latency by approximately 65%.
