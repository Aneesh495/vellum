# frozen_string_literal: true

module Vellum
  module Crypto
    # Abstract cryptographic sponge construction over a finite field F.
    # State has width t = rate + capacity.
    class Sponge
      attr_reader :field, :rate, :capacity, :width, :state

      def initialize(field, rate, capacity)
        @field = field
        @rate = rate
        @capacity = capacity
        @width = rate + capacity
        reset!
      end

      def reset!
        @state = Array.new(@width) { @field.zero }
        @absorbed = 0
      end

      # Absorbs field elements into the sponge
      def absorb(elements)
        elements.each do |elem|
          e = elem.is_a?(Algebra::FieldElement) ? elem : @field.element(elem)
          @state[@absorbed % @rate] += e
          @absorbed += 1

          permute! if (@absorbed % @rate).zero?
        end
      end

      # Squeezes field elements from the sponge
      def squeeze(num_elements = 1)
        permute! if (@absorbed % @rate).nonzero?
        @absorbed = 0

        result = []
        while result.length < num_elements
          chunk = @state[0...@rate]
          result.concat(chunk)
          permute! if result.length < num_elements
        end

        result[0...num_elements]
      end

      # Permutation function to be implemented by specific cipher/sponge (Poseidon, Rescue, etc.)
      def permute!
        raise NotImplementedError
      end
    end
  end
end
