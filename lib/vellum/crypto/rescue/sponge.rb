# frozen_string_literal: true

require_relative "../sponge"
require_relative "constants"
require_relative "../../algebra/fields/bn254_scalar"

module Vellum
  module Crypto
    module Rescue
      # Rescue-Prime algebraic hash function.
      # Utilizes forward and inverse power maps for post-quantum STARK security.
      class Sponge < Crypto::Sponge
        attr_reader :num_rounds, :round_constants, :mds, :alpha, :alpha_inv

        def initialize(field = Algebra::Fields::BN254Scalar.instance, rate = 2, capacity = 1)
          super(field, rate, capacity)
          @num_rounds = Constants::ROUNDS
          @round_constants = Constants.round_constants(field, @width, @num_rounds)
          @mds = Constants.mds_matrix(field, @width)
          @alpha = 5
          @alpha_inv = compute_alpha_inv(field.modulus, @alpha)
        end

        def permute!
          const_idx = 0

          @num_rounds.times do
            # 1. Forward S-box layer: x^alpha
            @width.times do |i|
              @state[i] = @state[i] ** @alpha
            end

            # Linear MDS layer
            apply_mds

            # Round constants addition
            @width.times do |i|
              @state[i] = @state[i] + @round_constants[const_idx + i]
            end
            const_idx += @width

            # 2. Inverse S-box layer: x^(1/alpha)
            @width.times do |i|
              @state[i] = @state[i] ** @alpha_inv
            end

            # Linear MDS layer
            apply_mds

            # Round constants addition
            @width.times do |i|
              @state[i] = @state[i] + @round_constants[const_idx + i]
            end
            const_idx += @width
          end
        end

        private

        def apply_mds
          new_state = Array.new(@width) { @field.zero }

          @width.times do |i|
            sum = @field.zero
            @width.times do |j|
              sum = sum + (@mds[i][j] * @state[j])
            end
            new_state[i] = sum
          end

          @state = new_state
        end

        def compute_alpha_inv(p, alpha)
          phi = p - 1
          # Extended GCD for alpha^-1 mod (p - 1)
          g, x, = extended_gcd(alpha, phi)
          raise FieldError, "alpha and p - 1 not coprime" unless g == 1

          x % phi
        end

        def extended_gcd(a, b)
          if a.zero?
            [b, 0, 1]
          else
            g, x, y = extended_gcd(b % a, a)
            [g, y - (b / a) * x, x]
          end
        end
      end

      class << self
        def hash(elements, field: Algebra::Fields::BN254Scalar.instance, rate: 2, capacity: 1)
          sponge = Sponge.new(field, rate, capacity)
          sponge.absorb(elements)
          sponge.squeeze(1).first
        end

        def hash_2(left, right, field: Algebra::Fields::BN254Scalar.instance)
          hash([left, right], field: field, rate: 2, capacity: 1)
        end
      end
    end
  end
end
