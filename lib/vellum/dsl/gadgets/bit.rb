# frozen_string_literal: true

module Vellum
  module DSL
    module Gadgets
      # Bit decomposition and boolean constraint gadgets
      class BitGadget
        def self.to_bits(context, signal, num_bits = 64)
          context.assert_range(signal, num_bits)
        end

        def self.from_bits(context, bit_signals)
          bit_signals.each_with_index.reduce(Signal.new(context, 0)) do |acc, (b_sig, i)|
            acc + (b_sig * (1 << i))
          end
        end
      end
    end
  end
end
