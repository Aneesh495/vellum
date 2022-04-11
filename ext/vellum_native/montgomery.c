#include "vellum_native.h"

/* BN254 Base Field Modulus limbs:
   Hex: 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47 */
const vellum_u256_t BN254_FP_MODULUS = {
    .limbs = {
        0x3c208c16d87cfd47ULL,
        0x97816a916871ca8dULL,
        0xb85045b68181585dULL,
        0x30644e72e131a029ULL
    }
};

void vellum_u256_from_words(vellum_u256_t *dest, uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3) {
    dest->limbs[0] = w0;
    dest->limbs[1] = w1;
    dest->limbs[2] = w2;
    dest->limbs[3] = w3;
}

int vellum_u256_cmp(const vellum_u256_t *a, const vellum_u256_t *b) {
    for (int i = LIMBS_256 - 1; i >= 0; i--) {
        if (a->limbs[i] > b->limbs[i]) return 1;
        if (a->limbs[i] < b->limbs[i]) return -1;
    }
    return 0;
}

uint64_t vellum_u256_add(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b) {
    unsigned __int128 carry = 0;
    for (int i = 0; i < LIMBS_256; i++) {
        unsigned __int128 sum = (unsigned __int128)a->limbs[i] + b->limbs[i] + carry;
        r->limbs[i] = (uint64_t)sum;
        carry = sum >> 64;
    }
    return (uint64_t)carry;
}

uint64_t vellum_u256_sub(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b) {
    unsigned __int128 borrow = 0;
    for (int i = 0; i < LIMBS_256; i++) {
        unsigned __int128 diff = (unsigned __int128)a->limbs[i] - b->limbs[i] - borrow;
        r->limbs[i] = (uint64_t)diff;
        borrow = (diff >> 64) ? 1 : 0;
    }
    return (uint64_t)borrow;
}

/* Coarsely Integrated Operand Scanning (CIOS) Montgomery multiplication */
void vellum_mont_mul(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b,
                    const vellum_u256_t *mod, uint64_t inv) {
    uint64_t t[LIMBS_256 + 2] = {0};

    for (int i = 0; i < LIMBS_256; i++) {
        /* Step 1: Multiply and accumulate b[i] * a */
        unsigned __int128 carry = 0;
        uint64_t bi = b->limbs[i];

        for (int j = 0; j < LIMBS_256; j++) {
            unsigned __int128 prod = (unsigned __int128)bi * a->limbs[j] + t[j] + carry;
            t[j] = (uint64_t)prod;
            carry = prod >> 64;
        }
        unsigned __int128 sum = (unsigned __int128)t[LIMBS_256] + carry;
        t[LIMBS_256] = (uint64_t)sum;
        t[LIMBS_256 + 1] = sum >> 64;

        /* Step 2: Montgomery reduction step with factor m = t[0] * inv mod 2^64 */
        uint64_t m = t[0] * inv;
        carry = 0;

        unsigned __int128 prod = (unsigned __int128)m * mod->limbs[0] + t[0];
        carry = prod >> 64;

        for (int j = 1; j < LIMBS_256; j++) {
            prod = (unsigned __int128)m * mod->limbs[j] + t[j] + carry;
            t[j - 1] = (uint64_t)prod;
            carry = prod >> 64;
        }

        sum = (unsigned __int128)t[LIMBS_256] + carry;
        t[LIMBS_256 - 1] = (uint64_t)sum;
        t[LIMBS_256] = t[LIMBS_256 + 1] + (sum >> 64);
        t[LIMBS_256 + 1] = 0;
    }

    vellum_u256_t res;
    for (int i = 0; i < LIMBS_256; i++) {
        res.limbs[i] = t[i];
    }

    /* Final reduction if res >= modulus */
    if (t[LIMBS_256] || vellum_u256_cmp(&res, mod) >= 0) {
        vellum_u256_sub(&res, &res, mod);
    }

    *r = res;
}
