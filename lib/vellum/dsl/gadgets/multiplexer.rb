# frozen_string_literal: true

module Vellum
  module DSL
    module Gadgets
      # Multiplexer gadgets for conditional branching inside circuits
      class MultiplexerGadget
        # 2-to-1 Multiplexer: returns sig_0 if cond == 0, else sig_1
        def self.mux2(context, cond, sig_0, sig_1)
          # res = sig_0 + cond * (sig_1 - sig_0)
          sig_0 + (cond * (sig_1 - sig_0))
        end

        # N-to-1 Multiplexer: selects signal from array based on integer index
        def self.select(context, index_sig, signals)
          return signals.first if signals.length == 1

          res = Signal.new(context, 0)
          signals.each_with_index do |sig, i|
            # eq_i = is_equal(index_sig, i)
            eq_i = ComparatorGadget.is_equal(context, index_sig, Signal.new(context, i))
            res = res + (eq_i * sig)
          end
          res
        end
      end
    end
  end
end
