# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BabyJubJub scalar field Fr:
      # Curve order n = 21888242871839275222246405745257275088614511777268538073601725287587578984328
      # Subgroup order l = 2736030358979909402780800718157159386076813972158567259200215660948447373041
      class BabyJubJubScalar < PrimeField
        MODULUS = 21888242871839275222246405745257275088614511777268538073601725287587578984328
        SUBGROUP_ORDER = 2736030358979909402780800718157159386076813972158567259200215660948447373041
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
