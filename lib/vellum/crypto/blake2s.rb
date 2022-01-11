# frozen_string_literal: true

module Vellum
  module Crypto
    # Pure Ruby implementation of RFC 7693 BLAKE2s-256 cryptographic hash.
    # Optimized for 32-bit architectures, transparency in STARK FRI protocols,
    # and zero external C dependencies.
    class Blake2s
      IV = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
      ].freeze

      SIGMA = [
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
        [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
        [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
        [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
        [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
        [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
        [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
        [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
        [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0]
      ].freeze

      def initialize(digest_length = 32, key = "")
        raise ArgumentError, "Digest length must be 1..32" unless (1..32).cover?(digest_length)
        raise ArgumentError, "Key length must be 0..32" unless key.bytesize <= 32

        @digest_length = digest_length
        @h = IV.dup
        # Parameter block: digest_length, key_length, fanout=1, depth=1
        @h[0] ^= 0x01010000 ^ (key.bytesize << 8) ^ digest_length

        @buf = String.new(encoding: Encoding::BINARY)
        @total_bytes = 0

        unless key.empty?
          padded_key = key.b.ljust(64, "\0")
          update(padded_key)
        end
      end

      def update(data)
        bytes = data.b
        @buf << bytes
        while @buf.bytesize > 64
          block = @buf.byteslice(0, 64)
          @buf = @buf.byteslice(64..-1) || String.new(encoding: Encoding::BINARY)
          @total_bytes += 64
          compress(block, false)
        end
        self
      end
      alias << update

      def digest
        final_buf = @buf.b
        @total_bytes += final_buf.bytesize
        padded = final_buf.ljust(64, "\0")
        compress(padded, true)

        @h.pack("V8")[0...@digest_length]
      end

      def hexdigest
        digest.unpack1("H*")
      end

      private

      def compress(block, last_block)
        m = block.unpack("V16")
        v = Array.new(16)
        8.times { |i| v[i] = @h[i] }
        v[8] = IV[0]
        v[9] = IV[1]
        v[10] = IV[2]
        v[11] = IV[3]
        v[12] = IV[4] ^ (@total_bytes & 0xFFFFFFFF)
        v[13] = IV[5] ^ ((@total_bytes >> 32) & 0xFFFFFFFF)
        v[14] = last_block ? (IV[6] ^ 0xFFFFFFFF) : IV[6]
        v[15] = IV[7]

        10.times do |round|
          s = SIGMA[round]
          g(v, 0, 4, 8, 12, m[s[0]], m[s[1]])
          g(v, 1, 5, 9, 13, m[s[2]], m[s[3]])
          g(v, 2, 6, 10, 14, m[s[4]], m[s[5]])
          g(v, 3, 7, 11, 15, m[s[6]], m[s[7]])

          g(v, 0, 5, 10, 15, m[s[8]], m[s[9]])
          g(v, 1, 6, 11, 12, m[s[10]], m[s[11]])
          g(v, 2, 7, 8, 13, m[s[12]], m[s[13]])
          g(v, 3, 4, 9, 14, m[s[14]], m[s[15]])
        end

        8.times do |i|
          @h[i] = (@h[i] ^ v[i] ^ v[i + 8]) & 0xFFFFFFFF
        end
      end

      def g(v, a, b, c, d, x, y)
        v[a] = (v[a] + v[b] + x) & 0xFFFFFFFF
        v[d] = rotr32(v[d] ^ v[a], 16)
        v[c] = (v[c] + v[d]) & 0xFFFFFFFF
        v[b] = rotr32(v[b] ^ v[c], 12)

        v[a] = (v[a] + v[b] + y) & 0xFFFFFFFF
        v[d] = rotr32(v[d] ^ v[a], 8)
        v[c] = (v[c] + v[d]) & 0xFFFFFFFF
        v[b] = rotr32(v[b] ^ v[c], 7)
      end

      def rotr32(val, shift)
        ((val >> shift) | (val << (32 - shift))) & 0xFFFFFFFF
      end

      class << self
        def digest(data)
          new.update(data).digest
        end

        def hexdigest(data)
          new.update(data).hexdigest
        end
      end
    end
  end
end
