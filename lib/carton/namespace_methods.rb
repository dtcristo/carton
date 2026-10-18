# frozen_string_literal: true

module Carton
  # Hash-like lookup helpers for `Carton::Namespace`.
  module NamespaceMethods
    # Support destructuring like `import('math') => { add: }`.
    def deconstruct_keys(keys)
      keys.each_with_object({}) do |key, hash|
        found, value = lookup_entry(key)
        hash[key] = value if found
      end
    end

    # Return the member or `nil`.
    def [](key)
      found, value = lookup_entry(key)
      found ? value : nil
    end

    # Check whether the lookup will succeed.
    def key?(key)
      lookup_entry(key).first
    end

    alias has_key? key?

    # Fetch a member with the same default/block semantics as `Hash#fetch`.
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

    # Member names as Symbols: helpers first, then constants.
    def keys = lookup_names.map(&:to_sym)

    # Every member by name: helpers as `Method` objects, constants as set.
    def to_h = keys.to_h { |key| [key, self[key]] }

    # Fetch several members and raise if any are missing.
    def fetch_values(*keys)
      keys.map { |key| fetch(key) }
    end

    # Return several members, using `nil` for missing keys.
    def values_at(*keys)
      keys.map { |key| self[key] }
    end
  end
end
