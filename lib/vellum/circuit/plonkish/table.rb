# frozen_string_literal: true

require_relative "gate"
require_relative "../../algebra/evaluation_domain"
require_relative "../../algebra/ntt"
require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module Plonkish
      # Execution trace table for Plonkish arithmetization.
      # Columns: 3 wire columns (a, b, c) and 5 selector columns (qL, qR, qO, qM, qC).
      class Table
        attr_reader :field, :gates, :wire_a, :wire_b, :wire_c, :domain

        def initialize(field, capacity = 8)
          @field = field
          @gates = []
          @wire_a = []
          @wire_b = []
          @wire_c = []
          @capacity = capacity
        end

        def add_row(gate, a_val, b_val, c_val)
          @gates << gate
          @wire_a << (@field.element(a_val))
          @wire_b << (@field.element(b_val))
          @wire_c << (@field.element(c_val))
        end

        def num_rows
          @gates.length
        end

        def satisfied?
          num_rows.times do |i|
            return false unless @gates[i].satisfied?(@wire_a[i], @wire_b[i], @wire_c[i])
          end
          true
        end

        # Padds trace table to next power of 2 and initializes evaluation domain
        def finalize!
          n = [num_rows, 2].max
          @domain = Algebra::EvaluationDomain.new(@field, n)
          pad_len = @domain.size - num_rows

          pad_len.times do
            add_row(Gate.new(@field.zero, @field.zero, @field.zero, @field.zero, @field.zero), 0, 0, 0)
          end
        end

        # Interpolates column evaluations into polynomials over domain H via iNTT
        def column_polynomial(col_name)
          raise StateError, "Table not finalized" unless @domain

          evals = case col_name
                  when :a then @wire_a
                  when :b then @wire_b
                  when :c then @wire_c
                  when :ql then @gates.map(&:ql)
                  when :qr then @gates.map(&:qr)
                  when :qo then @gates.map(&:qo)
                  when :qm then @gates.map(&:qm)
                  when :qc then @gates.map(&:qc)
                  else raise ArgumentError, "Unknown column: #{col_name}"
                  end

          coeffs = Algebra::NTT.inverse(evals, @domain)
          Algebra::Polynomial.new(@field, coeffs)
        end
      end
    end
  end
end
