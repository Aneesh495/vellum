# frozen_string_literal: true

require_relative "../elliptic_curve"
require_relative "../fields/bls12_381_base"
require_relative "../fields/bls12_381_scalar"

module Vellum
  module Algebra
    module Curves
      # BLS12-381 G1 curve: y^2 = x^3 + 4 over Fq.
      class BLS12381G1 < EllipticCurve
        G1_X = 3685416753713387016781088315183077757961620795782546409894578378688607592378376318836054947676345821548104185464507
        G1_Y = 133950654494447647302047137994192122158493386593117690052646005607720013899952815802142205538749798410256262652222

        def initialize
          fq = Fields::BLS12381Base.instance
          super(fq, 0, 4, order: Fields::BLS12381Scalar::MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.generator
          instance.generator
        end

        def generator
          @generator ||= point(G1_X, G1_Y)
        end
      end
    end
  end
end
