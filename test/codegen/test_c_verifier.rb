# frozen_string_literal: true

require_relative "../test_helper"
require "vellum"
require "vellum/codegen/c_verifier"

class TestCVerifier < Minitest::Test
  def setup
    @circuit = Vellum.circuit do
      x = private_input(:x)
      out = public_input(:out)
      assert_equal(x * x, out, "sq")
    end
    _, @vk = @circuit.setup
  end

  def test_c_verifier_generation
    c_code = Vellum::Codegen::CVerifier.generate(@vk)
    refute_nil c_code
    assert_includes c_code, "G1Point"
    assert_includes c_code, "G2Point"
    assert_includes c_code, "bool vellum_verify"
    assert_includes c_code, "int main"

    refute_includes c_code, "\u2014", "Generated C code must not contain em dashes"
  end

  def test_c_code_syntax_validation
    c_code = Vellum::Codegen::CVerifier.generate(@vk)

    # Check syntax using clang if available
    compiler = system("which clang > /dev/null 2>&1") ? "clang" : (system("which gcc > /dev/null 2>&1") ? "gcc" : nil)
    if compiler
      IO.popen("#{compiler} -x c -fsyntax-only -", "w") do |pipe|
        pipe.write(c_code)
      end
      assert_equal 0, $?.exitstatus, "Generated C code must be syntactically valid C99"
    end
  end
end
