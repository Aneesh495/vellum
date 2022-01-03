# frozen_string_literal: true

require_relative "../prime_field"

module Vellum
  module Algebra
    module Fields
      # BLS12-381 base field Fq:
      # q = 40024095552216673934177898257359041565568828199390078853320581361240316333788327581472051770619876171882353225563
      class BLS12381Base < PrimeField
        MODULUS = 40024095552216673934177898257359041565568828199390078853320581361240316333788327581472051770619876171882353225563

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
