# frozen_string_literal: true

require_relative "../test_helper"
require "vellum/crypto/merkle_tree"
require "vellum/algebra/fields/bn254_scalar"

class TestMerkleTree < Minitest::Test
  def setup
    @field = Vellum::Algebra::Fields::BN254Scalar.instance
    @leaves = (1..8).map { |i| @field.element(i * 100) }
  end

  def test_poseidon_merkle_tree_proof_and_verification
    tree = Vellum::Crypto::MerkleTree.new(@leaves, :poseidon)
    refute_nil tree.root

    # Verify proof for each leaf
    @leaves.each_with_index do |leaf, idx|
      proof = tree.prove(idx)
      assert_equal leaf, proof.leaf
      assert_equal idx, proof.index
      assert_equal tree.root, proof.root

      # Self-verification
      assert proof.verify, "Valid Merkle proof must verify successfully"

      # Static verification
      assert Vellum::Crypto::MerkleTree.verify(leaf, proof.path, tree.root, :poseidon)
    end
  end

  def test_blake2s_merkle_tree
    string_leaves = %w[alpha beta gamma delta epsilon zeta eta theta]
    tree = Vellum::Crypto::MerkleTree.new(string_leaves, :blake2s)

    string_leaves.each_with_index do |leaf, idx|
      proof = tree.prove(idx)
      assert proof.verify
    end
  end

  def test_corrupted_merkle_proof_rejected
    tree = Vellum::Crypto::MerkleTree.new(@leaves, :poseidon)
    proof = tree.prove(2)

    # Corrupt leaf
    wrong_leaf = @field.element(999999)
    refute Vellum::Crypto::MerkleTree.verify(wrong_leaf, proof.path, tree.root, :poseidon)

    # Corrupt root
    wrong_root = @field.element(888888)
    refute Vellum::Crypto::MerkleTree.verify(proof.leaf, proof.path, wrong_root, :poseidon)
  end

  def test_odd_number_of_leaves
    odd_leaves = (1..5).map { |i| @field.element(i) }
    tree = Vellum::Crypto::MerkleTree.new(odd_leaves, :poseidon)

    5.times do |i|
      proof = tree.prove(i)
      assert proof.verify
    end
  end

  def test_index_out_of_bounds
    tree = Vellum::Crypto::MerkleTree.new(@leaves, :poseidon)
    assert_raises(IndexError) do
      tree.prove(10)
    end
  end
end
