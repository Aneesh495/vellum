# frozen_string_literal: true

module Vellum
  module Circuit
    # Represents a discrete wire in an arithmetic circuit.
    # Wires can represent public inputs, private witnesses, internal signals, or constants.
    class Variable
      attr_accessor :id
      attr_reader :name, :type

      TYPES = %i[constant public_input public_output private_witness internal].freeze

      def initialize(id, name, type = :internal)
        raise ArgumentError, "Invalid variable type: #{type}" unless TYPES.include?(type)

        @id = id
        @name = name.to_sym
        @type = type
      end

      def constant?
        @type == :constant
      end

      def public?
        @type == :public_input || @type == :public_output
      end

      def private?
        @type == :private_witness || @type == :internal
      end

      def to_s
        "#{@name}(#{@id})"
      end
      alias inspect to_s

      def ==(other)
        equal?(other) || (other.is_a?(Variable) && @id == other.id)
      end

      def eql?(other)
        equal?(other)
      end

      def hash
        object_id.hash
      end
    end
  end
end
