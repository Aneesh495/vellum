# frozen_string_literal: true

require_relative "../../algebra/evaluation_domain"
require_relative "../../algebra/ntt"
require_relative "../../algebra/polynomial"

module Vellum
  module Circuit
    module AIR
      # Two-dimensional execution trace for STARK computations.
      # Rows represent time steps t = 0..T-1; columns represent state registers.
      class Trace
        attr_reader :field, :num_steps, :num_registers, :matrix, :domain

        def initialize(field, num_registers, num_steps)
          @field = field
          @num_registers = num_registers
          # Next power of 2 for domain
          pow2_steps = 1 << Math.log2([num_steps, 2].max).ceil
          @num_steps = pow2_steps
          @domain = Algebra::EvaluationDomain.new(field, @num_steps)
          @matrix = Array.new(@num_steps) { Array.new(@num_registers) { field.zero } }
        end

        def set(step, register, val)
          v = val.is_a?(Algebra::FieldElement) ? val : @field.element(val)
          @matrix[step][register] = v
        end

        def get(step, register)
          @matrix[step][register]
        end

        def row(step)
          @matrix[step]
        end

        # Interpolates column register j into a polynomial over domain H via iNTT
        def register_polynomial(reg_idx)
          evals = Array.new(@num_steps) { |step| @matrix[step][reg_idx] }
          coeffs = Algebra::NTT.inverse(evals, @domain)
          Algebra::Polynomial.new(@field, coeffs)
        end

        # Computes Low-Degree Extension (LDE) of all registers by blowup_factor (e.g. 4x or 8x)
        # on a shifted coset domain to avoid zero denominators.
        def low_degree_extension(blowup_factor = 4, shift = 3)
          lde_size = @num_steps * blowup_factor
          lde_domain = Algebra::EvaluationDomain.new(@field, lde_size)
          shift_elem = @field.element(shift)

          extended_columns = Array.new(@num_registers)
          @num_registers.times do |reg_idx|
            poly = register_polynomial(reg_idx)
            # Evaluate on shifted coset domain via Coset-NTT
            extended_columns[reg_idx] = Algebra::NTT.coset_forward(poly.coeffs, lde_domain, shift_elem)
          end

          {
            domain: lde_domain,
            shift: shift_elem,
            columns: extended_columns
          }
        end
      end
    end
  end
end
