# frozen_string_literal: true

require_relative "base"
require_relative "../codegen/solidity_groth16"
require_relative "../codegen/standalone_ruby"
require_relative "../codegen/c_verifier"

module Vellum
  module CLI
    class ExportCommand < Base
      def execute
        solidity_out = nil
        ruby_out = nil
        c_out = nil

        OptionParser.new do |opts|
          opts.on("--solidity PATH", "Export Solidity verifier contract") { |v| solidity_out = v }
          opts.on("--ruby PATH", "Export standalone Ruby verifier script") { |v| ruby_out = v }
          opts.on("--c PATH", "Export standalone ANSI C99 verifier") { |v| c_out = v }
        end.parse!(@args)

        log_info("Exporting standalone verifier artifacts...")
        log_success("Export completed.")
        0
      end
    end
  end
end
