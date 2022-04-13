# frozen_string_literal: true

module Vellum
  module Native
    @loaded = false

    begin
      require "vellum_native"
      @loaded = true
    rescue LoadError
      begin
        require "vellum/vellum_native"
        @loaded = true
      rescue LoadError
        @loaded = false
      end
    end

    def self.available?
      @loaded
    end

    module Montgomery
      def self.available?
        Vellum::Native.available? && defined?(super) && super
      end
    end unless defined?(Montgomery)
  end
end
