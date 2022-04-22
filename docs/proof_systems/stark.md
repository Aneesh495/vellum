# Vellum: Scalable Transparent ARguments of Knowledge (STARKs)

STARKs are zero-knowledge proof systems with transparent setup (no toxic waste or ceremony required) and post-quantum security based solely on collision-resistant cryptographic hash functions and polynomial error-correcting codes.

---

## 1. Algebraic Intermediate Representation (AIR)

In the STARK framework, a computation is represented as an execution trace matrix $T$:
$$T \in \mathbb{F}^{T_{\text{len}} \times W}$$
where $T_{\text{len}} = 2^k$ is the trace length and $W$ is the number of registers (state width).

### 1.1 Boundary Constraints
Boundary constraints enforce that specific registers contain predetermined values at specific execution steps (e.g., initial inputs and final results):
$$P_{r}(g^i) = v$$
where $g$ generates the trace domain $D_{\text{trace}} = \{g^0, g^1, \dots, g^{T_{\text{len}}-1}\}$.
The boundary quotient polynomial is:
$$B_r(X) = \frac{P_r(X) - v}{X - g^i}$$

### 1.2 Transition Constraints
Transition constraints define the state update logic across consecutive cycles:
$$C(T_{r}(X), T_{r}(g X), \dots) = 0 \quad \forall X \in D_{\text{trace}} \setminus \{g^{T_{\text{len}}-1}\}$$
The transition quotient is formed by dividing by the transition vanishing polynomial:
$$H(X) = \frac{C(X)}{Z_{\text{trans}}(X)}, \quad Z_{\text{trans}}(X) = \frac{X^{T_{\text{len}}} - 1}{X - g^{T_{\text{len}}-1}}$$

---

## 2. Low-Degree Extension (LDE)

To detect adulterated traces with overwhelming probability, the prover expands the execution trace using a Reed-Solomon code:
1. Interpolate each column $r \in \{0, \dots, W-1\}$ into a polynomial $P_r(X)$ of degree $< T_{\text{len}}$.
2. Select a larger evaluation domain $D_{\text{eval}}$ of size $N = \text{blowup} \times T_{\text{len}}$ (typically blowup $= 4$ or $8$).
3. Evaluate $P_r(X)$ on $D_{\text{eval}}$ using Coset NTT.
4. Construct a Merkle tree over the rows of the LDE matrix, committing to the root hash.

---

## 3. Fast Reed-Solomon Interactive Oracle Proof of Proximity (FRI)

FRI proves that a committed function $f_0: D_0 \to \mathbb{F}$ is close to a Reed-Solomon codeword of degree $< d$.

### 3.1 Commit Phase (Degree Halving)
At each layer $i \in \{0, \dots, r-1\}$, the verifier provides a random folding challenge $\alpha_i \in \mathbb{F}$. The prover folds the domain $D_i$ to $D_{i+1} = \{x^2 : x \in D_i\}$ and computes the folded polynomial:
$$f_{i+1}(X^2) = \frac{f_i(X) + f_i(-X)}{2} + \alpha_i \cdot \frac{f_i(X) - f_i(-X)}{2X}$$
This splits $f_i$ into even and odd components:
$$f_i(X) = g(X^2) + X \cdot h(X^2) \implies f_{i+1}(Y) = g(Y) + \alpha_i \cdot h(Y)$$
The degree is halved at each step until a constant or very low-degree polynomial remains. Each folded evaluation vector is committed to via a Merkle tree.

### 3.2 Query Phase
The verifier draws pseudorandom evaluation points $x \in D_0$ via Fiat-Shamir. For each query:
1. The prover reveals $f_i(x)$ and $f_i(-x)$ along with their Merkle authentication paths.
2. The verifier checks that the Merkle paths authenticate to the committed roots.
3. The verifier validates the colinearity relation:
   $$f_{i+1}(x^2) = \frac{f_i(x) + f_i(-x)}{2} + \alpha_i \cdot \frac{f_i(x) - f_i(-x)}{2x}$$

Any deviation from low degree creates errors that amplify across FRI folding rounds, leading to rejection with probability exceeding $1 - (1 - \delta)^{\text{queries}}$.
