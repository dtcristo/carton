# frozen_string_literal: true

module Carton
  # Shared lookup helpers for `Carton::Exports` and bare `Carton::Box` imports.
  module ExportMethods
    # Support destructuring like `import('math') => { add: }`.
    def deconstruct_keys(keys)
      return {} unless keys

      keys.each_with_object({}) do |key, hash|
        found, value = lookup_entry(key)
        hash[key] = value if found
      end
    end

    # Return the exported value or `nil`.
    def [](key)
      found, value = lookup_entry(key)
      found ? value : nil
    end

    # Check whether the export lookup will succeed.
    def key?(key)
      lookup_entry(key).first
    end

    alias has_key? key?

    # Fetch an exported value with the same default/block semantics as `Hash#fetch`.
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

    # Fetch several exported values and raise if any are missing.
    def fetch_values(*keys)
      keys.map { |key| fetch(key) }
    end

    # Return several exported values, using `nil` for missing keys.
    def values_at(*keys)
      keys.map { |key| self[key] }
    end
  end
end
