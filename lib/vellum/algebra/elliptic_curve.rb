# frozen_string_literal: true

require_relative "point"
require_relative "extension_field"

module Vellum
  module Algebra
    # Short Weierstrass elliptic curve y^2 = x^3 + a*x + b over a field F.
    class EllipticCurve
      attr_reader :field, :a, :b, :order, :cofactor

      def initialize(field, a, b, order: nil, cofactor: 1)
        @field = field
        @a = a.is_a?(FieldElement) || a.is_a?(ExtensionElement) ? a : field.element(a)
        @b = b.is_a?(FieldElement) || b.is_a?(ExtensionElement) ? b : field.element(b)
        @order = order
        @cofactor = cofactor
        @infinity = Point.new(self, field.zero, field.one, field.zero, infinity: true)
      end

      def infinity
        @infinity
      end

      def point(x, y, z = nil)
        Point.new(self, x, y, z)
      end

      def on_curve?(point)
        return true if point.infinity?

        p = point.to_affine
        lhs = p.y * p.y
        rhs = (p.x * p.x * p.x) + (@a * p.x) + @b
        lhs == rhs
      end

      def ==(other)
        other.is_a?(EllipticCurve) &&
          @field == other.field &&
          @a == other.a &&
          @b == other.b
      end
      alias eql? ==

      def hash
        [@field, @a, @b].hash
      end
    end

    # Twisted Edwards curve ax^2 + y^2 = 1 + dx^2 y^2.
    # Complete addition law without exceptional points.
    class TwistedEdwardsCurve
      attr_reader :field, :a, :d, :order, :subgroup_order

      def initialize(field, a, d, order: nil, subgroup_order: nil)
        @field = field
        @a = field.element(a)
        @d = field.element(d)
        @order = order
        @subgroup_order = subgroup_order
        @identity = EdwardsPoint.new(self, field.zero, field.one)
      end

      def identity
        @identity
      end
      alias infinity identity

      def point(x, y)
        EdwardsPoint.new(self, x, y)
      end

      def on_curve?(point)
        aff = point.to_affine
        x = aff.x
        y = aff.y
        lhs = (@a * x * x) + (y * y)
        rhs = @field.one + (@d * x * x * y * y)
        lhs == rhs
      end
    end

    # Point on a Twisted Edwards curve with projective extended coordinates (X:Y:Z:T)
    # where x = X/Z, y = Y/Z, x*y = T/Z.
    class EdwardsPoint
      attr_reader :curve, :x, :y, :z, :t

      def initialize(curve, x, y, z = nil, t = nil)
        @curve = curve
        f = curve.field
        @x = x.is_a?(FieldElement) ? x : f.element(x)
        @y = y.is_a?(FieldElement) ? y : f.element(y)
        @z = z ? (z.is_a?(FieldElement) ? z : f.element(z)) : f.one
        @t = t ? (t.is_a?(FieldElement) ? t : f.element(t)) : (@x * @y * @z.inv)
      end

      def infinity?
        aff = to_affine
        aff.x.zero? && aff.y.one?
      end
      alias identity? infinity?

      def to_affine
        return self if @z.one?

        z_inv = @z.inv
        EdwardsPoint.new(@curve, @x * z_inv, @y * z_inv, @curve.field.one)
      end

      # Extended projective twisted Edwards addition law:
      # A = (Y1 - X1)*(Y2 - X2)
      # B = (Y1 + X1)*(Y2 + X2)
      # C = T1 * 2 * d * T2
      # D = Z1 * 2 * Z2
      # E = B - A
      # F = D - C
      # G = D + C
      # H = B + a*A
      # X3 = E * F
      # Y3 = G * H
      # T3 = E * H
      # Z3 = F * G
      def +(other)
        a_param = @curve.a
        d_param = @curve.d

        a = @x * other.x
        b = @y * other.y
        c = @t * d_param * other.t
        d = @z * other.z

        e = ((@x + @y) * (other.x + other.y)) - a - b
        f = d - c
        g = d + c
        h = b - (a * a_param)

        x3 = e * f
        y3 = g * h
        t3 = e * h
        z3 = f * g

        EdwardsPoint.new(@curve, x3, y3, z3, t3)
      end

      def -@
        EdwardsPoint.new(@curve, -@x, @y, @z, -@t)
      end

      def -(other)
        self + (-other)
      end

      def *(scalar)
        k = scalar.to_i
        return @curve.identity if k.zero?
        return (-self) * (-k) if k.negative?

        res = @curve.identity
        curr = self

        while k.positive?
          res = res + curr if k.odd?
          curr = curr + curr
          k >>= 1
        end

        res
      end

      def ==(other)
        return false unless other.is_a?(EdwardsPoint)

        p1 = to_affine
        p2 = other.to_affine
        p1.x == p2.x && p1.y == p2.y
      end
      alias eql? ==

      def hash
        p = to_affine
        [p.x, p.y].hash
      end

      def to_s
        p = to_affine
        "EdwardsPoint(#{p.x}, #{p.y})"
      end
      alias inspect to_s
    end
  end
end
