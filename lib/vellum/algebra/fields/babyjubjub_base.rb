# frozen_string_literal: true

require_relative "bn254_scalar"

module Vellum
  module Algebra
    module Fields
      # BabyJubJub base field is the BN254 scalar field Fr.
      # This enables native, embedded, zero-overhead elliptic curve arithmetic
      # inside BN254 SNARK circuits!
      class BabyJubJubBase < BN254Scalar
        def self.instance
          @instance ||= new
        end
      end
    end
  end
end
