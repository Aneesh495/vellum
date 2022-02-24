# frozen_string_literal: true

require "json"

module Vellum
  module Utils
    # Codecs for serializing and deserializing circuits, keys, and proofs to JSON.
    module Serialization
      class << self
        def dump_json(obj, file_path)
          data = if obj.respond_to?(:to_h)
                   obj.to_h
                 else
                   obj
                 end
          File.write(file_path, JSON.pretty_generate(data))
        end

        def load_json(file_path)
          JSON.parse(File.read(file_path))
        end
      end
    end
  end
end
