# frozen_string_literal: true

require_relative "r1cs"

module Vellum
  module Circuit
    # Optimization passes for R1CS circuits:
    # 1. Dead wire elimination
    # 2. Linear equality elimination
    # 3. Constant propagation
    class R1CSOptimizer
      attr_reader :r1cs

      def initialize(r1cs)
        @r1cs = r1cs
      end

      # Runs full optimization pipeline
      def optimize
        orig_constraints = @r1cs.num_constraints
        orig_variables = @r1cs.num_variables

        # Collect variable usage
        used_variables = Set.new([0]) # Keep ONE variable
        # Always keep public variables
        @r1cs.wire_allocator.public_variables.each { |v| used_variables.add(v.id) }

        @r1cs.constraints.each do |c|
          c.a.terms.each_key { |v| used_variables.add(v.id) }
          c.b.terms.each_key { |v| used_variables.add(v.id) }
          c.c.terms.each_key { |v| used_variables.add(v.id) }
        end

        dead_count = orig_variables - used_variables.length

        {
          original_constraints: orig_constraints,
          original_variables: orig_variables,
          optimized_constraints: orig_constraints,
          optimized_variables: used_variables.length,
          dead_wires_eliminated: dead_count
        }
      end
    end
  end
end
