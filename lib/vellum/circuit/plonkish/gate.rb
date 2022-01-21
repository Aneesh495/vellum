# frozen_string_literal: true

module Vellum
  module Circuit
    module Plonkish
      # Represents a single Plonkish constraint gate:
      # q_L * a + q_R * b + q_O * c + q_M * (a * b) + q_C = 0
      class Gate
        attr_reader :ql, :qr, :qo, :qm, :qc, :gate_type

        def initialize(ql, qr, qo, qm, qc, gate_type = :custom)
          @ql = ql
          @qr = qr
          @qo = qo
          @qm = qm
          @qc = qc
          @gate_type = gate_type
        end

        def evaluate(a, b, c)
          (@ql * a) + (@qr * b) + (@qo * c) + (@qm * a * b) + @qc
        end

        def satisfied?(a, b, c)
          evaluate(a, b, c).zero?
        end

        # Factory methods for canonical gates
        def self.addition(field)
          new(field.one, field.one, -field.one, field.zero, field.zero, :add)
        end

        def self.multiplication(field)
          new(field.zero, field.zero, -field.one, field.one, field.zero, :mul)
        end

        def self.boolean(field)
          # a * a - a = 0 => q_M = 1, q_L = -1
          new(-field.one, field.zero, field.zero, field.one, field.zero, :bool)
        end

        def self.constant(field, val)
          c = val.is_a?(Algebra::FieldElement) ? val : field.element(val)
          new(field.one, field.zero, field.zero, field.zero, -c, :const)
        end
      end
    end
  end
end
