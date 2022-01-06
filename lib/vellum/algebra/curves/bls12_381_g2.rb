# frozen_string_literal: true

require_relative "../elliptic_curve"
require_relative "../extensions/fp2"
require_relative "../fields/bls12_381_base"
require_relative "../fields/bls12_381_scalar"

module Vellum
  module Algebra
    module Curves
      # BLS12-381 G2 sextic twist curve: y^2 = x^3 + 4*(1 + u) over Fq2.
      class BLS12381G2 < EllipticCurve
        G2_X = [
          3527010695874666181871391160110601448900299527927752402199086442397937857357150268733476010101956567023875139620051,
          3059144344244213709079978448247615089599281396076383787216186516012469086392523555914357242412232009514635213745856
        ].freeze

        G2_Y = [
          198515060228729193556805457878959865630801424439969178227182523099879058982629404286756623260136706335011147769949,
          178458173604970897009764536762948074209328779422002578426733288365387636689620220343355934753997955567681190552729
        ].freeze

        def initialize
          fq = Fields::BLS12381Base.instance
          fp2 = Extensions::Fp2.new(fq, -1)
          b_prime = fp2.element([4, 4]) # 4 + 4*u
          super(fp2, fp2.zero, b_prime, order: Fields::BLS12381Scalar::MODULUS)
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
