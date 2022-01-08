# frozen_string_literal: true

module Vellum
  module Algebra
    module Pairing
      # Abstract interface and multi-pairing combinators for bilinear pairings
      # e: G1 x G2 -> GT.
      class PairingEngine
        # Evaluates the multi-pairing product:
        # prod(e(p_i, q_i)) for array of pairs [[p_0, q_0], [p_1, q_1], ...]
        def multi_pairing(pairs)
          raise NotImplementedError
        end

        # Evaluates single pairing e(p, q)
        def pairing(p, q)
          multi_pairing([[p, q]])
        end

        # Evaluates if product of pairings equals 1 in GT:
        # prod(e(p_i, q_i)) == 1
        def check_pairing_identity(pairs)
          res = multi_pairing(pairs)
          res.one?
        end
      end
    end
  end
end
