# frozen_string_literal: true

require_relative "context"
require_relative "../prover/groth16"
require_relative "../verifier/groth16"

module Vellum
  module DSL
    # Top-level DSL builder for authoring arithmetic circuits.
    class Builder
      def self.build(field = Algebra::Fields::BN254Scalar.instance, &block)
        context = Context.new(field)
        context.instance_eval(&block)
        context.finalize!
        CompiledCircuit.new(context)
      end
    end

    # High-level executable representation of a compiled arithmetic circuit.
    class CompiledCircuit
      attr_reader :context, :r1cs

      def initialize(context)
        @context = context
        @r1cs = context.r1cs
      end

      def num_constraints
        @r1cs.num_constraints
      end

      def num_variables
        @r1cs.num_variables
      end

      def num_public
        @r1cs.num_public
      end

      def num_private
        @r1cs.num_private
      end

      # Generates Groth16 proving and verifying keys
      def setup(pairing_engine = Algebra::Pairing::BN254Pairing.instance)
        Prover::Groth16.setup(@r1cs, pairing_engine)
      end

      # Synthesizes full witness vector from named inputs
      def synthesize(input_map)
        @context.synthesize(input_map)
      end

      # Proves knowledge of witness for circuit
      def prove(pk, input_map)
        witness = synthesize(input_map)
        Prover::Groth16.prove(pk, witness)
      end

      # Verifies proof against public inputs
      def verify(vk, public_inputs, proof, pairing_engine = Algebra::Pairing::BN254Pairing.instance)
        pub_vec = public_inputs.is_a?(Array) ? public_inputs : extract_public_inputs(public_inputs)
        Verifier::Groth16.verify(vk, pub_vec, proof, pairing_engine)
      end

      private

      def extract_public_inputs(input_map)
        @r1cs.wire_allocator.public_variables.map do |var|
          val = input_map[var.name] || input_map[var.name.to_s]
          raise ArgumentError, "Missing public input: #{var.name}" if val.nil?

          val
        end
      end
    end
  end
end
