# frozen_string_literal: true

module Package
  module ExportMethods
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

    def fetch(key, *default)
      if default.size > 1
        raise ArgumentError,
              "wrong number of arguments (given #{default.size + 1}, expected 1..2)"
      end

      found, value = lookup_entry(key)
      return value if found
      return yield key if block_given?
      return default.first unless default.empty?

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
