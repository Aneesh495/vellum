# frozen_string_literal: true

require "optparse"
require_relative "../tui/ansi"

module Vellum
  module CLI
    # Base class for CLI subcommands
    class Base
      attr_reader :args

      def initialize(args)
        @args = args
      end

      def execute
        raise NotImplementedError
      end

      protected

      def log_info(msg)
        puts "#{TUI::ANSI.cyan('[Vellum]')} #{msg}"
      end

      def log_success(msg)
        puts "#{TUI::ANSI.green('[Vellum:Success]')} #{msg}"
      end

      def log_error(msg)
        warn "#{TUI::ANSI.red('[Vellum:Error]')} #{msg}"
      end
    end
  end
end
