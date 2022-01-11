# frozen_string_literal: true

require_relative "blake2s"

module Vellum
  module Crypto
    # Merlin-style Fiat-Shamir transcript protocol for non-interactive zero-knowledge proofs.
    # Maintains domain separation and absorbs protocol messages (commitments, public inputs)
    # to squeeze pseudorandom scalar challenges.
    class FiatShamir
      def initialize(label = "vellum-protocol")
        @state = Blake2s.new
        absorb_label(label)
      end

      # Absorbs a protocol domain label
      def absorb_label(label)
        bytes = label.b
        @state.update([bytes.bytesize].pack("V"))
        @state.update(bytes)
      end

      # Absorbs raw binary bytes
      def absorb_bytes(label, data)
        absorb_label(label)
        bytes = data.b
        @state.update([bytes.bytesize].pack("V"))
        @state.update(bytes)
      end

      # Absorbs a finite field element
      def absorb_element(label, element)
        absorb_bytes(label, element.to_bytes(:little))
      end

      # Absorbs an elliptic curve point
      def absorb_point(label, point)
        absorb_label(label)
        if point.infinity?
          absorb_bytes("#{label}_inf", "\x01")
        else
          aff = point.to_affine
          absorb_element("#{label}_x", aff.x)
          absorb_element("#{label}_y", aff.y)
        end
      end

      # Squeezes a scalar challenge in the specified field
      def squeeze_challenge(label, field)
        absorb_label(label)
        # Squeeze 64 bytes for bias-free modular reduction
        h1 = @state.hexdigest
        @state.update(h1)
        h2 = @state.hexdigest

        raw_int = (h1 + h2).to_i(16)
        field.element(raw_int % field.modulus)
      end

      # Squeezes multiple scalar challenges
      def squeeze_challenges(label, count, field)
        Array.new(count) { |i| squeeze_challenge("#{label}_#{i}", field) }
      end
    end
  end
end
