# frozen_string_literal: true

require_relative "signal"
require_relative "../circuit/r1cs"
require_relative "../algebra/fields/bn254_scalar"

module Vellum
  module DSL
    # Execution and compilation context for arithmetic circuits.
    # Manages wire allocation, signal instantiation, witness computation hints,
    # and constraint accumulation.
    class Context
      attr_reader :field, :r1cs, :signals, :witness_hints

      def initialize(field = Algebra::Fields::BN254Scalar.instance)
        @field = field
        @r1cs = Circuit::R1CS.new(field)
        @signals = {}
        @witness_hints = {}
      end

      # Declares a public input signal
      def public_input(name)
        var = @r1cs.wire_allocator.allocate_public(name, :public_input)
        sig = Signal.new(self, var)
        @signals[name.to_sym] = sig
        sig
      end

      # Declares a private witness signal
      def private_input(name)
        var = @r1cs.wire_allocator.allocate_private(name, :private_witness)
        sig = Signal.new(self, var)
        @signals[name.to_sym] = sig
        sig
      end

      # Declares an array of public input signals
      def public_inputs(name, count)
        Array.new(count) { |i| public_input("#{name}_#{i}") }
      end

      # Declares an array of private witness signals
      def private_inputs(name, count)
        Array.new(count) { |i| private_input("#{name}_#{i}") }
      end

      # Allocates an internal signal
      def signal(name = nil)
        var = @r1cs.wire_allocator.allocate_internal(name || "sig")
        Signal.new(self, var)
      end

      # Registers a runtime witness calculation hint for an internal wire
      def add_witness_hint(variable, &hint_block)
        @witness_hints[variable] = hint_block
      end

      # Finalizes circuit construction by re-indexing wire allocation
      def finalize!
        @r1cs.wire_allocator.reindex!
      end

      # Asserts that two signals or expressions are equal: sig_a == sig_b
      def assert_equal(sig_a, sig_b, label = nil)
        s_a = coerce_signal(sig_a)
        s_a.assert_equal(sig_b, label)
      end

      # Asserts that signal is boolean (0 or 1)
      def assert_bit(sig, label = nil)
        s = coerce_signal(sig)
        s.assert_bit(label)
      end

      # Asserts that signal value lies in [0, 2^bits - 1] via bit decomposition
      def assert_range(sig, bits = 64, label = nil)
        s = coerce_signal(sig)
        bit_signals = Array.new(bits) { signal("bit") }

        # 1. Enforce that each decomposed signal is a bit
        bit_signals.each(&:assert_bit)

        # 2. Enforce sum(2^i * bit_i) == sig
        reconstructed = bit_signals.each_with_index.reduce(Signal.new(self, 0)) do |acc, (b_sig, i)|
          acc + (b_sig * (1 << i))
        end

        assert_equal(reconstructed, s, label || "range_check_#{bits}bit")

        # Hint for bit decomposition during witness generation
        bit_signals.each_with_index do |b_sig, i|
          var = b_sig.lc.terms.keys.first
          add_witness_hint(var) do |witness|
            val = s.lc.evaluate(witness).value
            (val >> i) & 1
          end
        end

        bit_signals
      end

      # Synthesizes full witness vector from user-provided inputs
      def synthesize(input_map)
        witness = Array.new(@r1cs.num_variables)
        witness[0] = @field.one

        # 1. Populate explicitly provided inputs
        input_map.each do |k, v|
          var = @r1cs.wire_allocator[k]
          raise ArgumentError, "Unknown input wire: #{k}" unless var

          val = v.is_a?(Algebra::FieldElement) ? v : @field.element(v)
          witness[var.id] = val
        end

        # 2. Iteratively compute internal wires using registered witness hints
        # Multiple passes in topological order until all wires are populated
        max_passes = @r1cs.num_variables + 5
        passes = 0

        while witness.any?(&:nil?)
          passes += 1
          raise SynthesisError, "Witness generation loop detected" if passes > max_passes

          progress = false
          @witness_hints.each do |var, hint|
            var_id = var.is_a?(Circuit::Variable) ? var.id : var
            next unless witness[var_id].nil?

            begin
              res = hint.call(witness)
              if res
                witness[var_id] = res.is_a?(Algebra::FieldElement) ? res : @field.element(res)
                progress = true
              end
            rescue SynthesisError
              # Dependent wires not ready yet in this pass
              next
            end
          end

          break unless progress
        end

        # Check if all wires are resolved
        witness.each_with_index do |val, idx|
          if val.nil?
            var = @r1cs.wire_allocator[idx]
            raise SynthesisError, "Unassigned wire: #{var ? var.name : idx}"
          end
        end

        # Verify satisfaction
        audit = @r1cs.audit(witness)
        unless audit[:satisfied]
          violations = audit[:violations].map { |v| "#{v[:label]}: #{v[:constraint]}" }.join(", ")
          raise ConstraintError, "Synthesized witness violates constraints: #{violations}"
        end

        witness
      end

      private

      def coerce_signal(obj)
        if obj.is_a?(Signal)
          obj
        else
          Signal.new(self, obj)
        end
      end
    end
  end
end
