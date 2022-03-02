require "securerandom"
require_relative "field_element"

module Vellum
  module Algebra
    # Prime finite field F_p implementing modular arithmetic, inversion via
    # extended Euclidean algorithm, Tonelli-Shanks square roots, and Montgomery form.
    class PrimeField
      attr_reader :modulus, :bit_length, :byte_length

      def initialize(modulus)
        raise ArgumentError, "Modulus must be > 1" unless modulus.is_a?(Integer) && modulus > 1

        @modulus = modulus
        @bit_length = modulus.bit_length
        @byte_length = (@bit_length + 7) / 8
        @zero = FieldElement.new(self, 0)
        @one = FieldElement.new(self, 1)
      end

      def element(val)
        FieldElement.new(self, val)
      end

      def zero
        @zero
      end

      def one
        @one
      end

      def random_element
        element(SecureRandom.random_number(@modulus))
      end

      def mod_pow(base, exp)
        base.pow(exp, @modulus)
      end

      def inv(val)
        val = val % @modulus
        raise ZeroDivisionError, "Inverse of zero does not exist" if val.zero?

        # Extended Euclidean algorithm: a*x + b*y = gcd(a, b)
        g, x, = extended_gcd(val, @modulus)
        raise FieldError, "#{val} and #{@modulus} are not coprime" unless g == 1

        x % @modulus
      end

      def legendre_symbol(val)
        val = val % @modulus
        return 0 if val.zero?

        res = mod_pow(val, (@modulus - 1) / 2)
        res == @modulus - 1 ? -1 : res
      end

      def quadratic_residue?(val)
        legendre_symbol(val) == 1
      end

      # Tonelli-Shanks algorithm for square root modulo an odd prime p.
      # Solves r^2 = val (mod p). Returns integer root or nil if non-residue.
      def sqrt(val)
        val = val % @modulus
        return 0 if val.zero?
        return nil unless quadratic_residue?(val)

        # Case 1: p = 3 (mod 4)
        if (@modulus % 4) == 3
          return mod_pow(val, (@modulus + 1) / 4)
        end

        # Factor p - 1 as q * 2^s with q odd
        q = @modulus - 1
        s = 0
        while q.even?
          q >>= 1
          s += 1
        end

        # Find quadratic non-residue z
        z = 2
        while legendre_symbol(z) != -1
          z += 1
        end

        c = mod_pow(z, q)
        r = mod_pow(val, (q + 1) / 2)
        t = mod_pow(val, q)
        m = s

        while t != 1
          # Find lowest i such that t^(2^i) = 1
          i = 1
          temp = (t * t) % @modulus
          while temp != 1
            temp = (temp * temp) % @modulus
            i += 1
            break if i >= m
          end

          b = mod_pow(c, 1 << (m - i - 1))
          r = (r * b) % @modulus
          c = (b * b) % @modulus
          t = (t * c) % @modulus
          m = i
        end

        # Deterministic choice: choose the smaller root
        alt = @modulus - r
        r < alt ? r : alt
      end

      def from_bytes(bytes, endian = :little)
        b = endian == :little ? bytes.reverse : bytes
        val = b.unpack1("H*").to_i(16)
        element(val)
      end

      def ==(other)
        other.is_a?(PrimeField) && @modulus == other.modulus
      end
      alias eql? ==

      def hash
        @modulus.hash
      end

      def to_s
        "F_#{@modulus.to_s(16)[0..7]}...#{@modulus.to_s(16)[-6..]}"
      end

      private

      def extended_gcd(a, b)
        if a.zero?
          [b, 0, 1]
        else
          g, x, y = extended_gcd(b % a, a)
          [g, y - (b / a) * x, x]
        end
      end
    end

    # Montgomery representation for ultra-fast repeated modular multiplication
    # without division. Operates using REDC reduction over R = 2^(64*k).
    class MontgomeryField < PrimeField
      attr_reader :r, :r2, :r_inv, :n_prime, :num_limbs

      def initialize(modulus)
        super(modulus)
        # Choose R as power of 2 greater than modulus
        @num_limbs = (@bit_length + 63) / 64
        @r = 1 << (@num_limbs * 64)
        @r2 = (@r * @r) % @modulus
        @r_inv = inv_mod(@r, @modulus)
        @n_prime = compute_n_prime(@modulus)
      end

      def to_montgomery(val)
        redc(val * @r2)
      end

      def from_montgomery(mont_val)
        redc(mont_val)
      end

      def mont_mul(a_mont, b_mont)
        redc(a_mont * b_mont)
      end

      # REDC algorithm: computes (t * R^-1) mod N
      def redc(t)
        mask = @r - 1
        m = ((t & mask) * @n_prime) & mask
        u = (t + m * @modulus) >> (@num_limbs * 64)
        u >= @modulus ? u - @modulus : u
      end

      private

      def inv_mod(a, m)
        g, x, = extended_gcd(a, m)
        raise FieldError, "Inverse does not exist" unless g == 1
        x % m
      end

      def compute_n_prime(modulus)
        # Compute n' = -N^-1 mod 2^64
        # Using Newton-Raphson Hensel inversion
        inv = 1
        6.times do
          inv = (inv * (2 - modulus * inv)) & 0xFFFFFFFFFFFFFFFF
        end
        (-inv) & 0xFFFFFFFFFFFFFFFF
      end
    end
  end
end
