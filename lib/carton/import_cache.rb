# frozen_string_literal: true

module Carton
  # Process-wide record of loaded Cartons, keyed by Entrypoint path.
  #
  # The Main Box creates one instance and every Carton Box receives that same
  # object, so each Entrypoint loads once no matter which Carton imports it.
  # Ruby objects are shared across Boxes; only definitions are Box-local, so
  # the Main Box's loader builds every Carton. A cached value is then a
  # value or `Carton::Exports` from the Main Box regardless of which
  # Carton imported it first.
  class ImportCache
    def initialize(&loader)
      @loader = loader
      @values = {}
      @gem_usage = {}
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
      if @values.key?(key)
        check_gem_versions(key, target)
        return @values[key]
      end
      raise ImportError, "circular import: #{key}" if @loading.key?(key)

      @loading[key] = true
      begin
        @values[key] = @loader.call(target)
        @gem_usage[key] = target.gem_usage || -> { target.gems }
        @values[key]
      ensure
        @loading.delete(key)
      end
    end

    # A cached Carton keeps the gem versions its first importer gave it: its
    # closure and the locked gems it has loaded, including any loaded lazily
    # since. Raise instead of silently sharing it with an importer that
    # activates or locks another version of one.
    def check_gem_versions(key, target)
      wanted = versions([*target.locked_gems, *target.gems])
      return if wanted.empty?

      versions(@gem_usage.fetch(key).call).each do |name, version|
        next if wanted.fetch(name, version) == version

        raise ImportError,
              "#{key} was imported with #{name} #{version}, " \
                "but this import activates #{name} #{wanted[name]}"
      end
    end

    def versions(specs)
      (specs || []).to_h { |spec| [spec.name, spec.version.to_s] }
    end
  end
end
