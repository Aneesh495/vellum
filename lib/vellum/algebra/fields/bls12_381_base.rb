# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BLS12-381 base field Fq:
      # q = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
      class BLS12381Base < PrimeField
        MODULUS = 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end
      end
    end
  end
end
