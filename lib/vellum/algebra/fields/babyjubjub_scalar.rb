# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BabyJubJub scalar field Fr:
      # r = 21888242871839275222246405745257275088614511777268538073601725288765267128927
      # Subgroup order l = r / 8 = 2736030358979909402780800718157159386076813972158567259200215661095658391116
      class BabyJubJubScalar < PrimeField
        MODULUS = 21888242871839275222246405745257275088614511777268538073601725288765267128927
        SUBGROUP_ORDER = 2736030358979909402780800718157159386076813972158567259200215661095658391116
        COFACTOR = 8

        def initialize
          super(MODULUS)
        end

        def self.instance
          @instance ||= new
        end

        def self.element(val)
          instance.element(val)
        end

        def subgroup_order
          SUBGROUP_ORDER
        end

        def cofactor
          COFACTOR
        end
      end
    end
  end
end
