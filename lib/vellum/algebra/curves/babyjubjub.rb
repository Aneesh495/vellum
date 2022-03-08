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

        GEN_X = 995203441582195749578291179787384436505546430278305826713579947235728471134
        GEN_Y = 5472060717959818805561601436314318772137091100104008585924551046643952123905

        BASE8_X = 5299619240641551281634865583518297030282874472190772894086521144482721001553
        BASE8_Y = 16950150798460657717958625567821834550301663161624707787222815936182638968203

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

        def self.base8
          instance.base8
        end

        def generator
          @generator ||= point(GEN_X, GEN_Y)
        end

        def base8
          @base8 ||= point(BASE8_X, BASE8_Y)
        end
      end
    end
  end
end
