# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BLS12-381 scalar field Fr:
      # r = 52435875175126190479447740508185965837690552500527637822603658699938581184513
      # 2-adicity of 32
      class BLS12381Scalar < PrimeField
        MODULUS = 52435875175126190479447740508185965837690552500527637822603658699938581184513
        TWO_ADICITY = 32
        TWO_ADIC_ROOT_OF_UNITY = 102382273577394958236510309599277006998670968434109167092362046858762514520163

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end

        def generator
          element(7)
        end

        def two_adicity
          TWO_ADICITY
        end

        def two_adic_root_of_unity
          element(102382273577394958236510309599277006998670968434109167092362046858762514520163)
        end
      end
    end
  end
end
