# frozen_string_literal: true

module Carton
  # Process-wide record of loaded Cartons, keyed by Entrypoint path.
  #
  # The Main Box creates one instance and every Carton Box receives that same
  # object, so each Entrypoint loads once no matter which Carton imports it.
  # Ruby objects are shared across Boxes; only definitions are Box-local, so
  # the Main Box's loader builds every Carton. A cached value is then a
  # `Carton::Exports` or `Carton::Box` from the Main Box regardless of which
  # Carton imported it first.
  class ImportCache
    def initialize(&loader)
      @loader = loader
      @values = {}
      @loading = {}
      @lock = Thread::Mutex.new
    end

    # Load `target` once per Entrypoint path. Targets without an absolute
    # path are loaded uncached. Nested imports on the owning thread re-enter
    # without waiting on the lock.
    def import(target)
      return @loader.call(target) unless File.absolute_path?(target.feature)

      key = File.realpath(target.feature)
      return fetch(key, target) if @lock.owned?

      @lock.synchronize { fetch(key, target) }
    end

    private

    def fetch(key, target)
      return @values[key] if @values.key?(key)
      raise "circular import: #{key}" if @loading.key?(key)

      @loading[key] = true
      begin
        @values[key] = @loader.call(target)
      ensure
        @loading.delete(key)
      end
    end
  end
end
