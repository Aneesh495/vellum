#include "vellum_native.h"

static VALUE mVellum;
static VALUE mNative;
static VALUE mMontgomery;

static void rb_integer_to_u256(VALUE val, vellum_u256_t *dest) {
    memset(dest, 0, sizeof(vellum_u256_t));
    VALUE current = val;
    VALUE mask = ULL2NUM(0xFFFFFFFFFFFFFFFFULL);

    for (int i = 0; i < LIMBS_256; i++) {
        if (current == INT2FIX(0)) break;
        VALUE limb_val = rb_funcall(current, rb_intern("&"), 1, mask);
        dest->limbs[i] = NUM2ULL(limb_val);
        current = rb_funcall(current, rb_intern(">>"), 1, INT2FIX(64));
    }
}

static VALUE u256_to_rb_integer(const vellum_u256_t *src) {
    VALUE res = INT2FIX(0);
    for (int i = LIMBS_256 - 1; i >= 0; i--) {
        res = rb_funcall(res, rb_intern("<<"), 1, INT2FIX(64));
        res = rb_funcall(res, rb_intern("+"), 1, ULL2NUM(src->limbs[i]));
    }
    return res;
}

static VALUE rb_native_available(VALUE self) {
    (void)self;
    return Qtrue;
}

static VALUE rb_mont_mul(VALUE self, VALUE rb_a, VALUE rb_b, VALUE rb_mod, VALUE rb_inv) {
    (void)self;
    vellum_u256_t a, b, mod, r;
    uint64_t inv = NUM2ULL(rb_inv);

    rb_integer_to_u256(rb_a, &a);
    rb_integer_to_u256(rb_b, &b);
    rb_integer_to_u256(rb_mod, &mod);

    vellum_mont_mul(&r, &a, &b, &mod, inv);

    return u256_to_rb_integer(&r);
}

void Init_vellum_native(void) {
    mVellum = rb_define_module("Vellum");
    mNative = rb_define_module_under(mVellum, "Native");
    mMontgomery = rb_define_module_under(mNative, "Montgomery");

    rb_define_singleton_method(mNative, "available?", rb_native_available, 0);
    rb_define_singleton_method(mMontgomery, "available?", rb_native_available, 0);
    rb_define_singleton_method(mMontgomery, "mul", rb_mont_mul, 4);
}
