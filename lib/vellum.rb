# frozen_string_literal: true

require_relative "vellum/version"

module Vellum
  class Error < StandardError; end
  class FieldError < Error; end
  class CurveError < Error; end
  class PairingError < Error; end
  class PolynomialError < Error; end
  class ConstraintError < Error; end
  class SynthesisError < Error; end
  class VerificationError < Error; end
  class ProofError < Error; end

  class << self
    def circuit(&block)
      require_relative "vellum/dsl/builder"
      DSL::Builder.build(&block)
    end
  end
end
