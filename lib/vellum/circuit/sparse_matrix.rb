# frozen_string_literal: true

module Vellum
  module Circuit
    # High-performance sparse matrix representation for R1CS constraint matrices.
    # Supports Coordinate list (COO) construction and matrix-vector multiplication.
    class SparseMatrix
      attr_reader :field, :num_rows, :num_cols, :entries

      def initialize(field, num_rows, num_cols)
        @field = field
        @num_rows = num_rows
        @num_cols = num_cols
        # Array of [row, col, val]
        @entries = []
        @row_map = Hash.new { |h, k| h[k] = {} }
      end

      def set(row, col, val)
        v = val.is_a?(Algebra::FieldElement) ? val : @field.element(val)
        return if v.zero?

        @entries << [row, col, v]
        @row_map[row][col] = v
      end

      def get(row, col)
        @row_map[row][col] || @field.zero
      end

      # Sparse matrix-vector product: M * v
      def mul_vector(vec)
        result = Array.new(@num_rows) { @field.zero }
        @entries.each do |row, col, val|
          v_elem = vec[col] || @field.zero
          result[row] += (val * v_elem)
        end
        result
      end

      def density
        total = @num_rows * @num_cols
        return 0.0 if total.zero?

        @entries.length.to_f / total
      end

      def non_zeros
        @entries.length
      end
    end
  end
end
