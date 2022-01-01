# frozen_string_literal: true

require_relative "lib/vellum/version"

Gem::Specification.new do |spec|
  spec.name          = "vellum"
  spec.version       = Vellum::VERSION
  spec.authors       = ["Aneesh Krishna"]
  spec.email         = ["aneeshkrishnaparthasarathy@gmail.com"]

  spec.summary       = "Zero-knowledge proof synthesis and verifiable computation engine in pure Ruby"
  spec.description   = "Vellum is an arithmetic circuit abstract machine, cryptographic proof engine, and domain-specific language implementing Groth16, Plonk, and STARKs from first principles in Ruby."
  spec.homepage      = "https://github.com/Aneesh495/vellum"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir        = "bin"
  spec.executables   = ["vellum"]
  spec.require_paths = ["lib"]
end
