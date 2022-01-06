# frozen_string_literal: true

require_relative "../elliptic_curve"
require_relative "../fields/bn254_base"
require_relative "../fields/bn254_scalar"

module Vellum
  module Algebra
    module Curves
      # BN254 / alt_bn128 G1 curve: y^2 = x^3 + 3 over Fq.
      class BN254G1 < EllipticCurve
        def initialize
          fq = Fields::BN254Base.instance
          super(fq, 0, 3, order: Fields::BN254Scalar::MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        # Standard canonical G1 generator point: (1, 2)
        def self.generator
          instance.generator
        end

        def generator
          @generator ||= point(1, 2)
        end
      end
    end
  end
end
