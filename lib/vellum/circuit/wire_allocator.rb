# frozen_string_literal: true

require_relative "variable"

module Vellum
  module Circuit
    # Allocates and manages wire identifiers for an arithmetic circuit.
    # Enforces standard R1CS wire ordering:
    # Wire 0: constant ONE
    # Wires 1..l: public inputs and outputs
    # Wires (l+1)..(m-1): private witnesses and internal signals.
    class WireAllocator
      attr_reader :variables, :public_variables, :private_variables, :one_variable

      def initialize
        @variables = []
        @public_variables = []
        @private_variables = []
        @by_name = {}

        # Wire 0 is always the constant ONE
        @one_variable = Variable.new(0, :ONE, :constant)
        @variables << @one_variable
        @by_name[:ONE] = @one_variable
      end

      def allocate_public(name, type = :public_input)
        raise ArgumentError, "Variable #{name} already exists" if @by_name.key?(name.to_sym)

        id = @variables.length
        var = Variable.new(id, name, type)
        @variables << var
        @public_variables << var
        @by_name[name.to_sym] = var
        var
      end

      def allocate_private(name, type = :private_witness)
        raise ArgumentError, "Variable #{name} already exists" if @by_name.key?(name.to_sym)

        id = @variables.length
        var = Variable.new(id, name, type)
        @variables << var
        @private_variables << var
        @by_name[name.to_sym] = var
        var
      end

      def allocate_internal(prefix = "aux")
        id = @variables.length
        name = "#{prefix}_#{id}".to_sym
        var = Variable.new(id, name, :internal)
        @variables << var
        @private_variables << var
        @by_name[name] = var
        var
      end

      # Re-indexes wires to enforce strict canonical ordering:
      # Wire 0: ONE
      # Wires 1..num_public: public inputs / outputs
      # Wires (num_public + 1)...num_variables: private witness and internal auxiliary wires.
      def reindex!
        @one_variable.id = 0
        new_vars = [@one_variable]
        new_by_name = { ONE: @one_variable }

        current_id = 1
        @public_variables.each do |var|
          var.id = current_id
          new_vars << var
          new_by_name[var.name] = var
          current_id += 1
        end

        @private_variables.each do |var|
          var.id = current_id
          new_vars << var
          new_by_name[var.name] = var
          current_id += 1
        end

        @variables = new_vars
        @by_name = new_by_name
        self
      end

      def [](name_or_id)
        if name_or_id.is_a?(Integer)
          @variables[name_or_id]
        else
          @by_name[name_or_id.to_sym]
        end
      end

      def num_variables
        @variables.length
      end

      def num_public
        @public_variables.length
      end

      def num_private
        @private_variables.length
      end
    end
  end
end
