#include "vellum_native.h"

/* G1 point addition and doubling in Jacobian coordinates */
void vellum_g1_double(vellum_g1_point_t *r, const vellum_g1_point_t *p,
                      const vellum_u256_t *mod, uint64_t inv) {
    if (p->infinity) {
        *r = *p;
        return;
    }

    vellum_u256_t a, b, c, d, e, f, x3, y3, z3, temp;

    /* a = x^2 */
    vellum_mont_mul(&a, &p->x, &p->x, mod, inv);
    /* b = y^2 */
    vellum_mont_mul(&b, &p->y, &p->y, mod, inv);
    /* c = b^2 */
    vellum_mont_mul(&c, &b, &b, mod, inv);

    /* d = 2 * ((x + b)^2 - a - c) */
    vellum_u256_add(&temp, &p->x, &b);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_mont_mul(&d, &temp, &temp, mod, inv);
    vellum_u256_sub(&d, &d, &a);
    vellum_u256_sub(&d, &d, &c);
    vellum_u256_add(&d, &d, &d);
    if (vellum_u256_cmp(&d, mod) >= 0) vellum_u256_sub(&d, &d, mod);

    /* e = 3 * a */
    vellum_u256_add(&temp, &a, &a);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_u256_add(&e, &temp, &a);
    if (vellum_u256_cmp(&e, mod) >= 0) vellum_u256_sub(&e, &e, mod);

    /* f = e^2 */
    vellum_mont_mul(&f, &e, &e, mod, inv);

    /* x3 = f - 2*d */
    vellum_u256_add(&temp, &d, &d);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_u256_sub(&x3, &f, &temp);

    /* y3 = e * (d - x3) - 8*c */
    vellum_u256_sub(&temp, &d, &x3);
    vellum_mont_mul(&y3, &e, &temp, mod, inv);

    vellum_u256_add(&temp, &c, &c);
    vellum_u256_add(&temp, &temp, &temp);
    vellum_u256_add(&temp, &temp, &temp);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_u256_sub(&y3, &y3, &temp);

    /* z3 = 2 * y * z */
    vellum_mont_mul(&z3, &p->y, &p->z, mod, inv);
    vellum_u256_add(&z3, &z3, &z3);
    if (vellum_u256_cmp(&z3, mod) >= 0) vellum_u256_sub(&z3, &z3, mod);

    r->x = x3;
    r->y = y3;
    r->z = z3;
    r->infinity = false;
}

void vellum_g1_add(vellum_g1_point_t *r, const vellum_g1_point_t *p, const vellum_g1_point_t *q,
                   const vellum_u256_t *mod, uint64_t inv) {
    if (p->infinity) {
        *r = *q;
        return;
    }
    if (q->infinity) {
        *r = *p;
        return;
    }

    vellum_u256_t z1z1, z2z2, u1, u2, s1, s2, h, i_term, j_term, r_term, v_term, temp;

    vellum_mont_mul(&z1z1, &p->z, &p->z, mod, inv);
    vellum_mont_mul(&z2z2, &q->z, &q->z, mod, inv);

    vellum_mont_mul(&u1, &p->x, &z2z2, mod, inv);
    vellum_mont_mul(&u2, &q->x, &z1z1, mod, inv);

    vellum_mont_mul(&temp, &q->z, &z2z2, mod, inv);
    vellum_mont_mul(&s1, &p->y, &temp, mod, inv);

    vellum_mont_mul(&temp, &p->z, &z1z1, mod, inv);
    vellum_mont_mul(&s2, &q->y, &temp, mod, inv);

    if (vellum_u256_cmp(&u1, &u2) == 0) {
        if (vellum_u256_cmp(&s1, &s2) == 0) {
            vellum_g1_double(r, p, mod, inv);
            return;
        }
        r->infinity = true;
        return;
    }

    vellum_u256_sub(&h, &u2, &u1);

    vellum_u256_add(&i_term, &h, &h);
    if (vellum_u256_cmp(&i_term, mod) >= 0) vellum_u256_sub(&i_term, &i_term, mod);
    vellum_mont_mul(&i_term, &i_term, &i_term, mod, inv);

    vellum_mont_mul(&j_term, &h, &i_term, mod, inv);

    vellum_u256_sub(&r_term, &s2, &s1);
    vellum_u256_add(&r_term, &r_term, &r_term);
    if (vellum_u256_cmp(&r_term, mod) >= 0) vellum_u256_sub(&r_term, &r_term, mod);

    vellum_mont_mul(&v_term, &u1, &i_term, mod, inv);

    /* x3 = r^2 - j - 2*v */
    vellum_mont_mul(&r->x, &r_term, &r_term, mod, inv);
    vellum_u256_sub(&r->x, &r->x, &j_term);
    vellum_u256_sub(&r->x, &r->x, &v_term);
    vellum_u256_sub(&r->x, &r->x, &v_term);

    /* y3 = r * (v - x3) - 2 * s1 * j */
    vellum_u256_sub(&temp, &v_term, &r->x);
    vellum_mont_mul(&r->y, &r_term, &temp, mod, inv);
    vellum_mont_mul(&temp, &s1, &j_term, mod, inv);
    vellum_u256_add(&temp, &temp, &temp);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_u256_sub(&r->y, &r->y, &temp);

    /* z3 = ((z1 + z2)^2 - z1z1 - z2z2) * h */
    vellum_u256_add(&temp, &p->z, &q->z);
    if (vellum_u256_cmp(&temp, mod) >= 0) vellum_u256_sub(&temp, &temp, mod);
    vellum_mont_mul(&r->z, &temp, &temp, mod, inv);
    vellum_u256_sub(&r->z, &r->z, &z1z1);
    vellum_u256_sub(&r->z, &r->z, &z2z2);
    vellum_mont_mul(&r->z, &r->z, &h, mod, inv);

    r->infinity = false;
}
