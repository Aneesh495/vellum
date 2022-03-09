# frozen_string_literal: true

module Vellum
  module TUI
    # ANSI escape sequences, box-drawing glyphs, and styling helpers.
    module ANSI
      RESET     = "\e[0m"
      BOLD      = "\e[1m"
      DIM       = "\e[2m"
      ITALIC    = "\e[3m"
      UNDERLINE = "\e[4m"

      # Standard colors
      BLACK   = "\e[30m"
      RED     = "\e[31m"
      GREEN   = "\e[32m"
      YELLOW  = "\e[33m"
      BLUE    = "\e[34m"
      MAGENTA = "\e[35m"
      CYAN    = "\e[36m"
      WHITE   = "\e[37m"

      # Bright colors
      BRIGHT_BLACK   = "\e[90m"
      BRIGHT_RED     = "\e[91m"
      BRIGHT_GREEN   = "\e[92m"
      BRIGHT_YELLOW  = "\e[93m"
      BRIGHT_BLUE    = "\e[94m"
      BRIGHT_MAGENTA = "\e[95m"
      BRIGHT_CYAN    = "\e[96m"
      BRIGHT_WHITE   = "\e[97m"

      # Box-drawing glyphs
      BOX_H  = "─"
      BOX_V  = "│"
      BOX_TL = "┌"
      BOX_TR = "┐"
      BOX_BL = "└"
      BOX_BR = "┘"
      BOX_T_DOWN = "┬"
      BOX_T_UP   = "┴"
      BOX_T_RIGHT = "├"
      BOX_T_LEFT  = "┤"
      BOX_CROSS   = "┼"

      extend self

      def bold(text)
        "#{BOLD}#{text}#{RESET}"
      end

      def green(text)
        "#{GREEN}#{text}#{RESET}"
      end

      def red(text)
        "#{RED}#{text}#{RESET}"
      end

      def cyan(text)
        "#{CYAN}#{text}#{RESET}"
      end

      def yellow(text)
        "#{YELLOW}#{text}#{RESET}"
      end

      def blue(text)
        "#{BLUE}#{text}#{RESET}"
      end

      def magenta(text)
        "#{MAGENTA}#{text}#{RESET}"
      end

      def dim(text)
        "#{DIM}#{text}#{RESET}"
      end
    end
  end
end
