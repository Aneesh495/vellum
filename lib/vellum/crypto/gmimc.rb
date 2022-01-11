# frozen_string_literal: true

require_relative "sponge"
require_relative "../algebra/fields/bn254_scalar"

module Vellum
  module Crypto
    # GMiMC (Generalized Minimal Multiplications Curve) Feistel hash function.
    # Minimizes multi-exponentiation multiplications inside arithmetic circuits.
    class GMiMC < Sponge
      ROUNDS = 48

      attr_reader :round_constants

      def initialize(field = Algebra::Fields::BN254Scalar.instance, rate = 2, capacity = 1)
        super(field, rate, capacity)
        @round_constants = generate_constants(field, ROUNDS)
      end

      def permute!
        ROUNDS.times do |r|
          # Non-linear Feistel step: f(x) = (state[0] + C_r)^3
          c = @round_constants[r]
          temp = @state[0] + c
          f_val = temp * temp * temp

          # Add f_val to state[1]
          @state[1] = @state[1] + f_val

          # Cyclic left rotation of state elements
          first = @state.shift
          @state.push(first)
        end
      end

      private

      def generate_constants(field, num_rounds)
        constants = []
        seed = 0x514d694d43
        num_rounds.times do |i|
          seed = ((seed * 1103515245) + 12345) & 0x7FFFFFFF
          constants << field.element(seed % field.modulus)
        end
        constants
      end

      class << self
        def hash(elements, field: Algebra::Fields::BN254Scalar.instance, rate: 2, capacity: 1)
          sponge = new(field, rate, capacity)
          sponge.absorb(elements)
          sponge.squeeze(1).first
        end
      end
    end
  end
end
