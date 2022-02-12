# frozen_string_literal: true

require_relative "poseidon"

module Vellum
  module DSL
    module Gadgets
      # Verifiable Delay Function (VDF) hash chain gadget
      class HashChainGadget
        def self.compute(context, seed_sig, steps)
          curr = seed_sig
          steps.times do |i|
            curr = PoseidonGadget.hash(context, [curr, Signal.new(context, i)])
          end
          curr
        end
      end
    end
  end
end
