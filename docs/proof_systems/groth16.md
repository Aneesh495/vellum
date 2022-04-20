# Vellum: Groth16 Zero-Knowledge Proof Protocol

Groth16 (Eurocrypt 2016) is a pairing-based zero-knowledge succinct non-interactive argument of knowledge (zk-SNARK) with the shortest proof size (3 group elements: 2 in $G_1$, 1 in $G_2$) and fastest verification (3 pairings) in cryptographic literature.

---

## 1. Protocol Architecture

Given an R1CS constraint system over a prime field $\mathbb{F}_r$, let $w = [w_0, w_1, \dots, w_m]^T$ be the assignment vector where:
- $w_0 = 1$ (constant wire)
- $w_1, \dots, w_l$ (public instance $x$)
- $w_{l+1}, \dots, w_m$ (private witness $a$)

The system satisfies:
$$\left( \sum_{i=0}^m w_i A_i(X) \right) \cdot \left( \sum_{i=0}^m w_i B_i(X) \right) - \left( \sum_{i=0}^m w_i C_i(X) \right) = h(X) \cdot t(X)$$
where $t(X) = \prod_{j=0}^{n-1} (X - \omega^j)$ is the vanishing polynomial over the constraint domain.

---

## 2. Structured Reference String (SRS) Generation

The setup phase samples secret random field elements (toxic waste):
$$\tau, \alpha, \beta, \gamma, \delta \stackrel{\$}{\leftarrow} \mathbb{F}_r^\times$$

### Proving Key ($\text{pk}$)
$$\begin{aligned}
\text{pk} = \Big( & [\alpha]_1, [\beta]_1, [\delta]_1, \\
& \{ [\tau^i]_1 \}_{i=0}^{n-1}, \{ [\tau^i]_2 \}_{i=0}^{n-1}, [\beta]_2, [\delta]_2, \\
& \left\{ \left[ \frac{\beta A_i(\tau) + \alpha B_i(\tau) + C_i(\tau)}{\delta} \right]_1 \right\}_{i=l+1}^m, \\
& \left\{ \left[ \frac{\tau^i t(\tau)}{\delta} \right]_1 \right\}_{i=0}^{n-2} \Big)
\end{aligned}$$

### Verifying Key ($\text{vk}$)
$$\text{vk} = \left( [\alpha]_1, [\beta]_2, [\gamma]_2, [\delta]_2, \left\{ [IC_i]_1 = \left[ \frac{\beta A_i(\tau) + \alpha B_i(\tau) + C_i(\tau)}{\gamma} \right]_1 \right\}_{i=0}^l \right)$$

Once generated, the toxic waste tuple $(\tau, \alpha, \beta, \gamma, \delta)$ must be discarded.

---

## 3. Prover Algorithm

The prover receives the proving key $\text{pk}$, the public instance $x$, and the private witness $a$.

1. **Compute Quotient Polynomial**:
   Calculate $h(X) = \frac{A(X) B(X) - C(X)}{t(X)}$ using inverse NTT and polynomial multiplication.

2. **Draw Random Blinding Factors**:
   To guarantee statistical zero knowledge, sample independent random scalars:
   $$r, s \stackrel{\$}{\leftarrow} \mathbb{F}_r$$

3. **Synthesize Proof Elements**:
   Evaluate multi-scalar multiplications (MSMs):
   $$A = [\alpha]_1 + \sum_{i=0}^m w_i [A_i(\tau)]_1 + r [\delta]_1$$
   $$B = [\beta]_2 + \sum_{i=0}^m w_i [B_i(\tau)]_2 + s [\delta]_2$$
   $$C = \sum_{i=l+1}^m w_i \left[ \frac{\beta A_i(\tau) + \alpha B_i(\tau) + C_i(\tau)}{\delta} \right]_1 + \left[ \frac{h(\tau) t(\tau)}{\delta} \right]_1 + s A + r B - r s [\delta]_1$$

4. **Emit Proof**:
   $$\pi = (A \in G_1, B \in G_2, C \in G_1)$$
   Total size on BN254: 32 bytes ($G_1$) + 64 bytes ($G_2$) + 32 bytes ($G_1$) = 128 bytes (compressed).

---

## 4. Verifier Algorithm

Given the verifying key $\text{vk}$, public inputs $x = [x_1, \dots, x_l]$, and proof $\pi = (A, B, C)$:

1. **Accumulate Public Inputs**:
   Compute the public input commitment in $G_1$:
   $$IC = [IC_0]_1 + \sum_{i=1}^l x_i [IC_i]_1$$

2. **Evaluate the Pairing Equation**:
   Check whether the following bilinear relation holds:
   $$e(A, B) = e([\alpha]_1, [\beta]_2) \cdot e(IC, [\gamma]_2) \cdot e(C, [\delta]_2)$$

Equivalently, verifying that the product of four pairings evaluates to identity in $G_T$:
$$e(A, B) \cdot e(-IC, [\gamma]_2) \cdot e(-C, [\delta]_2) \cdot e(-[\alpha]_1, [\beta]_2) \stackrel{?}{=} 1 \in G_T$$

---

## 5. Security Guarantees

1. **Perfect Completeness**: If the witness $w$ satisfies all constraints, the pairing check evaluates to true with probability 1.
2. **Computational Knowledge Soundness**: In the Algebraic Group Model (AGM) under the $q$-Strong Diffie-Hellman and $q$-Target Diffie-Hellman assumptions, no polynomial-time adversary can forge a valid proof without possessing an explicit witness extractor.
3. **Statistical Zero Knowledge**: For any choice of witness satisfying the public inputs, the distribution of $(A, B, C)$ under uniform random $r, s \in \mathbb{F}_r$ is statistically indistinguishable from uniform random group elements satisfying the verification equation.
