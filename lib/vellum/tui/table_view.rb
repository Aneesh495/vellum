# frozen_string_literal: true

require_relative "ansi"

module Vellum
  module TUI
    # Unicode box-drawing table renderer with automatic column sizing.
    class TableView
      def initialize(headers, rows = [])
        @headers = headers.map(&:to_s)
        @rows = rows.map { |r| r.map(&:to_s) }
      end

      def add_row(row)
        @rows << row.map(&:to_s)
      end

      def render
        col_widths = @headers.map(&:length)
        @rows.each do |row|
          row.each_with_index do |cell, i|
            col_widths[i] = [col_widths[i] || 0, cell.length].max
          end
        end

        lines = []

        # Top border: ┌───┬───┐
        top = ANSI::BOX_TL + col_widths.map { |w| ANSI::BOX_H * (w + 2) }.join(ANSI::BOX_T_DOWN) + ANSI::BOX_TR
        lines << top

        # Header row: │ col1 │ col2 │
        header_cells = @headers.each_with_index.map do |h, i|
          " #{ANSI.bold(h.ljust(col_widths[i]))} "
        end
        lines << "#{ANSI::BOX_V}#{header_cells.join(ANSI::BOX_V)}#{ANSI::BOX_V}"

        # Header separator: ├───┼───┤
        sep = ANSI::BOX_T_RIGHT + col_widths.map { |w| ANSI::BOX_H * (w + 2) }.join(ANSI::BOX_CROSS) + ANSI::BOX_T_LEFT
        lines << sep

        # Data rows
        @rows.each do |row|
          cells = row.each_with_index.map do |c, i|
            " #{c.ljust(col_widths[i])} "
          end
          lines << "#{ANSI::BOX_V}#{cells.join(ANSI::BOX_V)}#{ANSI::BOX_V}"
        end

        # Bottom border: └───┴───┘
        bot = ANSI::BOX_BL + col_widths.map { |w| ANSI::BOX_H * (w + 2) }.join(ANSI::BOX_T_UP) + ANSI::BOX_BR
        lines << bot

        lines.join("\n")
      end
    end
  end
end
