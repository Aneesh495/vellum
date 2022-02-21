# frozen_string_literal: true

require_relative "ansi"

module Vellum
  module TUI
    # Visualizes circuit topology as ASCII flow diagrams and Graphviz DOT graphs.
    class CircuitVisualizer
      def self.to_dot(r1cs, title = "VellumCircuit")
        lines = []
        lines << "digraph #{title} {"
        lines << "  rankdir=LR;"
        lines << "  node [shape=box, style=rounded, fontname=\"Helvetica\"];"

        # Variables nodes
        r1cs.wire_allocator.variables.each do |v|
          color = case v.type
                  when :public_input then "#4CAF50"
                  when :public_output then "#2196F3"
                  when :private_witness then "#9C27B0"
                  else "#9E9E9E"
                  end
          lines << "  var_#{v.id} [label=\"#{v.name}\\n(#Id:#{v.id})\", color=\"#{color}\"];"
        end

        # Constraint gate nodes
        r1cs.constraints.each_with_index do |c, i|
          lbl = c.label ? "#{c.label}\\n(#C:#{i})" : "Constraint #{i}"
          lines << "  gate_#{i} [label=\"#{lbl}\\n[*]\"];"

          # Edges from input vars to gate
          c.a.terms.each_key do |v|
            lines << "  var_#{v.id} -> gate_#{i} [label=\"A\"];"
          end
          c.b.terms.each_key do |v|
            lines << "  var_#{v.id} -> gate_#{i} [label=\"B\"];"
          end
          # Edges from gate to output vars
          c.c.terms.each_key do |v|
            lines << "  gate_#{i} -> var_#{v.id} [label=\"C\"];"
          end
        end

        lines << "}"
        lines.join("\n")
      end

      def self.ascii_summary(r1cs)
        lines = []
        lines << ANSI.bold("Circuit Topology Summary:")
        lines << "  Constraints: #{r1cs.num_constraints}"
        lines << "  Variables:   #{r1cs.num_variables}"
        lines << "    Public:    #{r1cs.num_public}"
        lines << "    Private:   #{r1cs.num_private}"
        lines.join("\n")
      end
    end
  end
end
