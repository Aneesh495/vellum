# frozen_string_literal: true

require_relative "base"
require_relative "../tui/circuit_visualizer"

module Vellum
  module CLI
    class CompileCommand < Base
      def execute
        if @args.empty?
          log_error("Usage: vellum compile <circuit_file.rb> [--dot output.dot]")
          return 1
        end

        circuit_path = @args.first
        dot_path = nil

        OptionParser.new do |opts|
          opts.on("--dot PATH", "Output Graphviz DOT topology") { |v| dot_path = v }
        end.parse!(@args[1..])

        log_info("Compiling circuit: #{circuit_path}...")
        load File.expand_path(circuit_path)

        log_success("Circuit compiled successfully.")
        0
      end
    end
  end
end
