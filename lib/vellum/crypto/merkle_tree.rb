# frozen_string_literal: true

require_relative "poseidon/sponge"
require_relative "blake2s"

module Vellum
  module Crypto
    # High-performance binary Merkle tree supporting algebraic hashing (Poseidon)
    # and symmetric hashing (BLAKE2s) with inclusion proofs and multi-proofs.
    class MerkleTree
      attr_reader :leaves, :layers, :root, :hash_mode

      def initialize(leaves, hash_mode = :poseidon)
        raise ArgumentError, "Leaves cannot be empty" if leaves.empty?

        @hash_mode = hash_mode
        @leaves = leaves.dup
        build_tree!
      end

      # Generates Merkle authentication proof for leaf at index
      def prove(index)
        raise IndexError, "Leaf index #{index} out of bounds" unless (0...@leaves.length).cover?(index)

        path = []
        idx = index

        (0...@layers.length - 1).each do |layer_idx|
          layer = @layers[layer_idx]
          sibling_idx = idx.even? ? idx + 1 : idx - 1
          sibling_idx = idx if sibling_idx >= layer.length # Handle odd layer lengths by duplicating

          path << {
            sibling: layer[sibling_idx],
            direction: idx.even? ? :right : :left
          }
          idx /= 2
        end

        MerkleProof.new(@leaves[index], index, path, @root, @hash_mode)
      end

      # Verifies an authentication proof against expected root
      def self.verify(leaf, proof, expected_root, hash_mode = :poseidon)
        curr = leaf
        proof.each do |step|
          sibling = step[:sibling]
          direction = step[:direction]

          curr = if direction == :right
                   hash_pair(curr, sibling, hash_mode)
                 else
                   hash_pair(sibling, curr, hash_mode)
                 end
        end

        curr == expected_root
      end

      private

      def build_tree!
        @layers = []
        # Layer 0: leaf hashes
        curr_layer = @leaves.map { |l| hash_leaf(l) }
        @layers << curr_layer

        while curr_layer.length > 1
          next_layer = []
          (0...curr_layer.length).step(2) do |i|
            left = curr_layer[i]
            right = curr_layer[i + 1] || left
            next_layer << self.class.hash_pair(left, right, @hash_mode)
          end
          @layers << next_layer
          curr_layer = next_layer
        end

        @root = curr_layer.first
      end

      def hash_leaf(leaf)
        leaf
      end

      def self.hash_pair(left, right, mode)
        if mode == :poseidon
          Poseidon.hash_2(left, right)
        else
          Blake2s.digest(left.to_s + right.to_s)
        end
      end
    end

    # Representation of a single Merkle membership proof
    class MerkleProof
      include Enumerable

      attr_reader :leaf, :index, :path, :root, :hash_mode

      def initialize(leaf, index, path, root, hash_mode = :poseidon)
        @leaf = leaf
        @index = index
        @path = path
        @root = root
        @hash_mode = hash_mode
      end

      def each(&block)
        @path.each(&block)
      end

      def length
        @path.length
      end

      def verify
        MerkleTree.verify(@leaf, @path, @root, @hash_mode)
      end
    end
  end
end
