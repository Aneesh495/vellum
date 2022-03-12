# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "vellum"

module Vellum
  module TestHelpers
    def assert_field_element_equal(expected, actual, msg = nil)
      exp_val = expected.is_a?(Algebra::FieldElement) ? expected.value : expected
      act_val = actual.is_a?(Algebra::FieldElement) ? actual.value : actual
      assert_equal exp_val, act_val, msg || "Expected field elements to match: #{exp_val} vs #{act_val}"
    end

    def assert_point_on_curve(point, msg = nil)
      return if point.infinity?

      assert point.curve.on_curve?(point.x, point.y), msg || "Expected point #{point} to lie on curve #{point.curve}"
    end

    def assert_point_equal(expected, actual, msg = nil)
      if expected.infinity?
        assert actual.infinity?, "Expected point to be infinity"
      else
        refute actual.infinity?, "Expected point not to be infinity"
        assert_field_element_equal expected.x, actual.x, "Point X coordinates mismatch"
        assert_field_element_equal expected.y, actual.y, "Point Y coordinates mismatch"
      end
    end
  end
end

class Minitest::Test
  include Vellum::TestHelpers
end
