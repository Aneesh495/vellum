# frozen_string_literal: true

require_relative "constraint"
require_relative "wire_allocator"
require_relative "sparse_matrix"
require_relative "../algebra/fields/bn254_scalar"

module Vellum
  module Circuit
    # Rank-1 Constraint System (R1CS) representation.
    # Manages constraint equations, variable wiring, and matrix generation
    # for zero-knowledge proving backends.
    class R1CS
      attr_reader :field, :wire_allocator, :constraints

      def initialize(field = Algebra::Fields::BN254Scalar.instance)
        @field = field
        @wire_allocator = WireAllocator.new
        @constraints = []
      end

      def add_constraint(a, b, c, label = nil)
        lc_a = coerce_lc(a)
        lc_b = coerce_lc(b)
        lc_c = coerce_lc(c)

        constraint = Constraint.new(lc_a, lc_b, lc_c, label)
        @constraints << constraint
        constraint
      end

      def num_constraints
        @constraints.length
      end

      def num_variables
        @wire_allocator.num_variables
      end

      def num_public
        @wire_allocator.num_public
      end

      def num_private
        @wire_allocator.num_private
      end

      # Compiles constraints into sparse matrices A, B, C
      # of dimension (num_constraints x num_variables)
      def build_matrices
        m = num_constraints
        n = num_variables

        matrix_a = SparseMatrix.new(@field, m, n)
        matrix_b = SparseMatrix.new(@field, m, n)
        matrix_c = SparseMatrix.new(@field, m, n)

        @constraints.each_with_index do |c, row|
          c.a.terms.each do |var, val|
            matrix_a.set(row, var.id, val)
          end
          c.b.terms.each do |var, val|
            matrix_b.set(row, var.id, val)
          end
          c.c.terms.each do |var, val|
            matrix_c.set(row, var.id, val)
          end
        end

        [matrix_a, matrix_b, matrix_c]
      end

      # Verifies if witness vector satisfies all constraints
      def satisfied?(witness)
        witness_vec = normalize_witness(witness)
        mat_a, mat_b, mat_c = build_matrices

        az = mat_a.mul_vector(witness_vec)
        bz = mat_b.mul_vector(witness_vec)
        cz = mat_c.mul_vector(witness_vec)

        num_constraints.times do |i|
          return false unless (az[i] * bz[i]) == cz[i]
        end

        true
      end

      # Audits witness satisfaction and returns diagnostics for any violations
      def audit(witness)
        violations = []
        witness_vec = normalize_witness(witness)

        @constraints.each_with_index do |c, idx|
          diff = c.evaluate_difference(witness_vec)
          unless diff.zero?
            violations << {
              index: idx,
              label: c.label,
              constraint: c.to_s,
              difference: diff.to_s
            }
          end
        end

        {
          satisfied: violations.empty?,
          num_constraints: num_constraints,
          num_variables: num_variables,
          violations: violations
        }
      end

      private

      def coerce_lc(obj)
        if obj.is_a?(LinearCombination)
          obj
        elsif obj.is_a?(Variable)
          LinearCombination.from_variable(obj, @field)
        elsif obj.is_a?(Integer) || obj.is_a?(Algebra::FieldElement)
          LinearCombination.constant(@field, obj, @wire_allocator.one_variable)
        else
          raise TypeError, "Cannot coerce #{obj.class} to LinearCombination"
        end
      end

      def normalize_witness(witness)
        vec = Array.new(num_variables) { @field.zero }
        vec[0] = @field.one # Wire 0 is always 1

        if witness.is_a?(Hash)
          witness.each do |k, v|
            var = k.is_a?(Variable) ? k : @wire_allocator[k]
            next unless var

            val = v.is_a?(Algebra::FieldElement) ? v : @field.element(v)
            vec[var.id] = val
          end
        elsif witness.is_a?(Array)
          witness.each_with_index do |v, i|
            next if i >= num_variables

            val = v.is_a?(Algebra::FieldElement) ? v : @field.element(v)
            vec[i] = val
          end
        end

        vec
      end
    end
  end
end
