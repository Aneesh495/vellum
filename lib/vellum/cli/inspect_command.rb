# frozen_string_literal: true

require_relative "base"
require_relative "../tui/inspector"

module Vellum
  module CLI
    class InspectCommand < Base
      def execute
        if @args.empty?
          log_error("Usage: vellum inspect <circuit_file.rb>")
          return 1
        end

        circuit_path = @args.first
        log_info("Inspecting circuit: #{circuit_path}...")
        circuit = load File.expand_path(circuit_path)

        if circuit.is_a?(DSL::CompiledCircuit)
          TUI::Inspector.inspect_circuit(circuit.r1cs)
        else
          log_info("Circuit loaded.")
        end
        0
      end
    end
  end
end
