# frozen_string_literal: true

require_relative "ansi"
require_relative "table_view"
require_relative "sparkline"

module Vellum
  module TUI
    # Interactive circuit and witness inspector for terminal debugging.
    class Inspector
      def self.inspect_circuit(r1cs, witness = nil)
        puts ANSI.bold("=== Vellum Circuit Inspector ===")
        puts "Modulus: #{r1cs.field.to_s}"
        puts "Constraints: #{r1cs.num_constraints} | Variables: #{r1cs.num_variables} (Public: #{r1cs.num_public}, Private: #{r1cs.num_private})"
        puts ""

        # Variable Table
        var_headers = ["ID", "Name", "Type", "Assigned Value"]
        var_rows = r1cs.wire_allocator.variables.map do |v|
          val_str = if witness
                      val = witness[v] || witness[v.id]
                      val ? val.to_s(16) : ANSI.dim("unassigned")
                    else
                      ANSI.dim("none")
                    end
          [v.id.to_s, v.name.to_s, v.type.to_s, val_str]
        end

        puts ANSI.bold("Variables:")
        puts TableView.new(var_headers, var_rows).render
        puts ""

        # Constraints Table
        c_headers = ["Index", "Label", "Constraint (A * B == C)", "Status"]
        c_rows = r1cs.constraints.each_with_index.map do |c, i|
          status_str = if witness
                         c.satisfied?(witness) ? ANSI.green("SATISFIED") : ANSI.red("VIOLATED")
                       else
                         ANSI.dim("UNCHECKED")
                       end
          [i.to_s, c.label || "none", c.to_s, status_str]
        end

        puts ANSI.bold("Constraints:")
        puts TableView.new(c_headers, c_rows).render
        puts ""

        # Constraint complexity sparkline
        terms_per_constraint = r1cs.constraints.map do |c|
          c.a.terms.length + c.b.terms.length + c.c.terms.length
        end
        spark = Sparkline.render(terms_per_constraint)
        puts "Constraint Complexity Profile: #{spark}"
        puts ""
      end
    end
  end
end
