# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BN254 / alt_bn128 base field Fq:
      # q = 21888242871839275222246405745257275088696311157297823662689037894645226208583
      class BN254Base < PrimeField
        MODULUS = 21888242871839275222246405745257275088696311157297823662689037894645226208583

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end

        def self.zero
          instance.zero
        end

        def self.one
          instance.one
        end

        def self.random
          instance.random_element
        end

        def generator
          element(3)
        end
      end
    end
  end
end
