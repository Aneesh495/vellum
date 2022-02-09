# frozen_string_literal: true

require_relative "poseidon"
require_relative "multiplexer"

module Vellum
  module DSL
    module Gadgets
      # In-circuit Merkle tree membership proof verification gadget.
      # Verifies inclusion of private leaf inside a public Merkle root
      # across arbitrary tree depths using in-circuit Poseidon hashing.
      class MerkleGadget
        # Verifies Merkle membership and returns computed root signal
        def self.verify_membership(context, leaf_sig, path_elements, path_indices)
          depth = path_elements.length
          raise ArgumentError, "Path lengths mismatch" unless path_indices.length == depth

          curr = leaf_sig

          depth.times do |i|
            direction = path_indices[i]
            sibling = path_elements[i]

            # Constrain direction to be boolean (0 = left, 1 = right)
            direction.assert_bit("merkle_dir_#{i}")

            # If direction == 0 (left child): left = curr, right = sibling
            # If direction == 1 (right child): left = sibling, right = curr
            left = MultiplexerGadget.mux2(context, direction, curr, sibling)
            right = MultiplexerGadget.mux2(context, direction, sibling, curr)

            curr = PoseidonGadget.hash_2(context, left, right)
          end

          curr
        end
      end
    end
  end
end
