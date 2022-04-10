#ifndef VELLUM_NATIVE_H
#define VELLUM_NATIVE_H

#include <ruby.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#define LIMBS_256 4
#define LIMBS_512 8

typedef struct {
    uint64_t limbs[LIMBS_256];
} vellum_u256_t;

typedef struct {
    uint64_t limbs[LIMBS_512];
} vellum_u512_t;

typedef struct {
    vellum_u256_t x;
    vellum_u256_t y;
    vellum_u256_t z;
    bool infinity;
} vellum_g1_point_t;

/* BN254 Base Field Modulus limbs (little-endian):
   p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
   Hex: 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47 */
extern const vellum_u256_t BN254_FP_MODULUS;

/* Montgomery multiplication primitives */
void vellum_u256_from_words(vellum_u256_t *dest, uint64_t w0, uint64_t w1, uint64_t w2, uint64_t w3);
int vellum_u256_cmp(const vellum_u256_t *a, const vellum_u256_t *b);
uint64_t vellum_u256_add(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b);
uint64_t vellum_u256_sub(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b);

void vellum_mont_mul(vellum_u256_t *r, const vellum_u256_t *a, const vellum_u256_t *b,
                    const vellum_u256_t *mod, uint64_t inv);

/* Point arithmetic */
void vellum_g1_double(vellum_g1_point_t *r, const vellum_g1_point_t *p,
                      const vellum_u256_t *mod, uint64_t inv);
void vellum_g1_add(vellum_g1_point_t *r, const vellum_g1_point_t *p, const vellum_g1_point_t *q,
                   const vellum_u256_t *mod, uint64_t inv);

#endif /* VELLUM_NATIVE_H */
