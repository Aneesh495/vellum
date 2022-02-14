# frozen_string_literal: true

require_relative "comparator"

module Vellum
  module DSL
    module Gadgets
      # Zero-knowledge Sudoku puzzle solver verification gadget.
      # Verifies that a private 9x9 board configuration is a valid Sudoku solution
      # matching public puzzle clues without revealing any solution entries.
      class SudokuGadget
        EXPECTED_SUM = 45        # 1 + 2 + ... + 9
        EXPECTED_PROD = 362880   # 9!

        # Verifies valid Sudoku grid
        def self.verify_grid(context, grid_cells, public_clues = {})
          # 1. Enforce each cell in 1..9: prod_{k=1}^9 (cell - k) == 0
          9.times do |r|
            9.times do |c|
              cell = grid_cells[r][c]
              enforce_digit_range(context, cell)
            end
          end

          # 2. Enforce row sums and products
          9.times do |r|
            row = grid_cells[r]
            assert_permutation_of_digits(context, row, "row_#{r}")
          end

          # 3. Enforce column sums and products
          9.times do |c|
            col = Array.new(9) { |r| grid_cells[r][c] }
            assert_permutation_of_digits(context, col, "col_#{c}")
          end

          # 4. Enforce 3x3 box sums and products
          (0...9).step(3) do |br|
            (0...9).step(3) do |bc|
              box = []
              3.times do |dr|
                3.times do |dc|
                  box << grid_cells[br + dr][bc + dc]
                end
              end
              assert_permutation_of_digits(context, box, "box_#{br}_#{bc}")
            end
          end

          # 5. Enforce public clues: if clue provided at (r, c), grid[r][c] == clue
          public_clues.each do |(r, c), clue_val|
            cell = grid_cells[r][c]
            context.assert_equal(cell, Signal.new(context, clue_val), "clue_#{r}_#{c}")
          end
        end

        private

        def self.enforce_digit_range(context, cell)
          # (cell - 1) * (cell - 2) * ... * (cell - 9) == 0
          prod = (1..9).reduce(Signal.new(context, 1)) do |acc, digit|
            term = cell - Signal.new(context, digit)
            acc * term
          end
          context.assert_equal(prod, Signal.new(context, 0), "digit_range")
        end

        def self.assert_permutation_of_digits(context, cells, label)
          # Sum constraint
          sum = cells.reduce(Signal.new(context, 0)) { |acc, x| acc + x }
          context.assert_equal(sum, Signal.new(context, EXPECTED_SUM), "#{label}_sum")

          # Product constraint
          prod = cells.reduce(Signal.new(context, 1)) { |acc, x| acc * x }
          context.assert_equal(prod, Signal.new(context, EXPECTED_PROD), "#{label}_prod")
        end
      end
    end
  end
end
