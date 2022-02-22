# frozen_string_literal: true

module Vellum
  module TUI
    # Unicode sparkline renderer for constraint density and degree distributions.
    module Sparkline
      TICKS = %w[  ▂ ▃ ▄ ▅ ▆ ▇ █].freeze

      def self.render(values)
        return "" if values.empty?

        min = values.min.to_f
        max = values.max.to_f
        range = max - min
        range = 1.0 if range.zero?

        values.map do |v|
          normalized = (v - min) / range
          idx = (normalized * (TICKS.length - 1)).round
          TICKS[idx]
        end.join
      end
    end
  end
end
