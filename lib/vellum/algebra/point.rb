# frozen_string_literal: true

module Vellum
  module Algebra
    # Coordinate representations for points on an elliptic curve.
    # Supports Affine (x, y) and Jacobian (X:Y:Z) with fast addition and doubling.
    class Point
      attr_reader :curve, :x, :y, :z, :infinity

      def initialize(curve, x, y, z = nil, infinity: false)
        @curve = curve
        @infinity = infinity

        if @infinity
          @x = curve.field.zero
          @y = curve.field.one
          @z = curve.field.zero
        else
          @x = x.is_a?(FieldElement) || x.is_a?(ExtensionElement) ? x : curve.field.element(x)
          @y = y.is_a?(FieldElement) || y.is_a?(ExtensionElement) ? y : curve.field.element(y)
          @z = z ? (z.is_a?(FieldElement) || z.is_a?(ExtensionElement) ? z : curve.field.element(z)) : curve.field.one
        end
      end

      def infinity?
        @infinity || @z.zero?
      end

      def affine?
        @z.one? && !infinity?
      end

      # Converts Jacobian coordinates (X:Y:Z) to Affine (x, y) = (X/Z^2, Y/Z^3)
      def to_affine
        return self if infinity? || @z.one?

        z_inv = @z.inv
        z_inv2 = z_inv * z_inv
        z_inv3 = z_inv2 * z_inv

        Point.new(@curve, @x * z_inv2, @y * z_inv3, @curve.field.one)
      end

      def +(other)
        return other if infinity?
        return self if other.infinity?
        raise CurveError, "Points belong to different curves" unless @curve == other.curve

        # Complete Jacobian addition formula
        # x1 = X1, y1 = Y1, z1 = Z1
        # x2 = X2, y2 = Y2, z2 = Z2
        z1_sq = @z * @z
        z2_sq = other.z * other.z
        u1 = @x * z2_sq
        u2 = other.x * z1_sq
        s1 = @y * z2_sq * other.z
        s2 = other.y * z1_sq * @z

        if u1 == u2
          if s1 == s2
            return double
          else
            return @curve.infinity
          end
        end

        h = u2 - u1
        r = s2 - s1
        h2 = h * h
        h3 = h2 * h
        u1_h2 = u1 * h2

        x3 = (r * r) - h3 - (u1_h2 * 2)
        y3 = (r * (u1_h2 - x3)) - (s1 * h3)
        z3 = @z * other.z * h

        Point.new(@curve, x3, y3, z3)
      end

      def -(other)
        self + (-other)
      end

      def -@
        return self if infinity?

        Point.new(@curve, @x, -@y, @z)
      end

      # In-place Jacobian point doubling with a = 0 (BN254 & BLS12-381 have y^2 = x^3 + b)
      def double
        return self if infinity? || @y.zero?

        if @curve.a.zero?
          # Optimized doubling for a = 0:
          # A = X^2
          # B = Y^2
          # C = B^2
          # D = 2*((X+B)^2 - A - C) = 4*X*B
          # E = 3*A
          # F = E^2
          # X3 = F - 2*D
          # Y3 = E*(D - X3) - 8*C
          # Z3 = 2*Y*Z
          a = @x * @x
          b = @y * @y
          c = b * b
          d = (@x * b) * 4
          e = a * 3
          f = e * e
          x3 = f - (d * 2)
          y3 = (e * (d - x3)) - (c * 8)
          z3 = (@y * @z) * 2

          Point.new(@curve, x3, y3, z3)
        else
          # Generic Jacobian doubling with curve parameter a
          # delta = Z^2, gamma = Y^2, beta = X*gamma, alpha = 3*X^2 + a*delta^2
          delta = @z * @z
          gamma = @y * @y
          beta = @x * gamma
          alpha = (@x * @x * 3) + (@curve.a * delta * delta)
          x3 = (alpha * alpha) - (beta * 8)
          y3 = (alpha * ((beta * 4) - x3)) - (gamma * gamma * 8)
          z3 = (@y + @z) * (@y + @z) - gamma - delta

          Point.new(@curve, x3, y3, z3)
        end
      end

      # Scalar multiplication via windowed NAF (wNAF)
      def *(scalar)
        k = scalar.to_i
        return @curve.infinity if k.zero? || infinity?
        return (-self) * (-k) if k.negative?

        # Double-and-add algorithm
        res = @curve.infinity
        curr = self

        while k.positive?
          res = res + curr if k.odd?
          curr = curr.double
          k >>= 1
        end

        res
      end

      def ==(other)
        return false unless other.is_a?(Point)
        return true if infinity? && other.infinity?
        return false if infinity? || other.infinity?

        p1 = to_affine
        p2 = other.to_affine
        p1.x == p2.x && p1.y == p2.y
      end
      alias eql? ==

      def hash
        p = to_affine
        p.infinity? ? [nil, nil].hash : [p.x, p.y].hash
      end

      def to_s
        if infinity?
          "Point(Infinity)"
        else
          aff = to_affine
          "Point(#{aff.x}, #{aff.y})"
        end
      end
      alias inspect to_s
    end
  end
end
