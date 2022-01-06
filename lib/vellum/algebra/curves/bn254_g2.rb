# frozen_string_literal: true

require_relative "../elliptic_curve"
require_relative "../extensions/fp2"
require_relative "../fields/bn254_base"
require_relative "../fields/bn254_scalar"

module Vellum
  module Algebra
    module Curves
      # BN254 / alt_bn128 G2 sextic twist curve: y^2 = x^3 + b' over Fq2
      # where b' = 3 / (9 + u) = (27 - 3u) / 82 in Fq2.
      class BN254G2 < EllipticCurve
        # Standard G2 generator coordinates in Fq2 = Fq[u]/(u^2 + 1)
        G2_X = [
          10857046999023057135944570762261464401804724949826315570087140924103730248430,
          1155973203298638710799100402139228572340775206788589204875084990924375082729
        ].freeze

        G2_Y = [
          8495653923123431417604973247489279077895166113181649728607146857297999881827,
          4082367875863433681332203403145435568310576218852241470496102133263400388708
        ].freeze

        def initialize
          fq = Fields::BN254Base.instance
          fp2 = Extensions::Fp2.new(fq, -1)
          # b' = 3 / (9 + u)
          xi = fp2.element([9, 1])
          b_prime = fp2.element([3, 0]) / xi
          super(fp2, fp2.zero, b_prime, order: Fields::BN254Scalar::MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.generator
          instance.generator
        end

        def generator
          @generator ||= point(field.element(G2_X), field.element(G2_Y))
        end
      end
    end
  end
end
