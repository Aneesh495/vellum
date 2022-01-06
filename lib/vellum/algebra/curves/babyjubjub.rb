# frozen_string_literal: true

require_relative "../elliptic_curve"
require_relative "../fields/bn254_scalar"
require_relative "../fields/babyjubjub_scalar"

module Vellum
  module Algebra
    module Curves
      # BabyJubJub twisted Edwards curve:
      # a*x^2 + y^2 = 1 + d*x^2*y^2
      # Defined over the BN254 scalar field Fr.
      # Ideal for zero-knowledge embedded signature verification (EdDSA).
      class BabyJubJub < TwistedEdwardsCurve
        A = 168700
        D = 168696

        GEN_X = 995203441582195749578288595088786035345782329561000854654328203124827520973
        GEN_Y = 5472060717959818805561601436314318772137091100104008585924551046643952123905

        def initialize
          fr = Fields::BN254Scalar.instance
          super(
            fr,
            A,
            D,
            order: Fields::BabyJubJubScalar::MODULUS,
            subgroup_order: Fields::BabyJubJubScalar::SUBGROUP_ORDER
          )
        end

        def self.instance
          @instance ||= new
        end

        def self.generator
          instance.generator
        end

        def generator
          @generator ||= point(GEN_X, GEN_Y)
        end
      end
    end
  end
end
