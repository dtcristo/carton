# frozen_string_literal: true

module Package
  module ExportMethods
    UNSET_VALUE = Object.new.freeze
    private_constant :UNSET_VALUE

    def deconstruct_keys(keys)
      return {} unless keys

      keys.each_with_object({}) do |key, hash|
        found, value = lookup_entry(key)
        hash[key] = value if found
      end
    end

    def [](key)
      found, value = lookup_entry(key)
      found ? value : nil
    end

    def key?(key)
      lookup_entry(key).first
    end

    alias has_key? key?

    def fetch(key, default = UNSET_VALUE)
      found, value = lookup_entry(key)
      return value if found
      return yield key if block_given?
      return default unless default.equal?(UNSET_VALUE)

      raise KeyError, "key not found: #{key.inspect}"
    end

    def fetch_values(*keys)
      keys.map { |key| fetch(key) }
    end

    def values_at(*keys)
      keys.map { |key| self[key] }
    end
  end
end
