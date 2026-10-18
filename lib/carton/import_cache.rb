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
    # Returned by `claim` when the calling thread should load the Entrypoint.
    LOAD = Object.new.freeze
    private_constant :LOAD

    def initialize(&loader)
      @loader = loader
      @values = {}
      @gem_usage = {}
      # The thread loading each Entrypoint, while it loads.
      @loading = {}
      @lock = Thread::Mutex.new
      @loaded = Thread::ConditionVariable.new
    end

    # Load `target` once per Entrypoint path. Targets without an absolute
    # path are loaded uncached.
    #
    # The lock only guards this bookkeeping and is never held while an
    # Entrypoint runs, so an Entrypoint can start threads that import other
    # Cartons. An import of an Entrypoint another thread is loading waits
    # for that load; one the same thread is loading is a cycle.
    def import(target)
      return @loader.call(target) unless File.absolute_path?(target.feature)

      key = File.realpath(target.feature)
      cached = claim(key)
      return load_entry(key, target) if cached.equal?(LOAD)

      check_gem_versions(key, target)
      cached
    end

    private

    # The cached value, or LOAD once this thread owns loading `key`.
    def claim(key)
      @lock.synchronize do
        loop do
          return @values[key] if @values.key?(key)

          owner = @loading[key]
          if owner.nil?
            @loading[key] = Thread.current
            return LOAD
          end
          if owner == Thread.current
            raise ImportError, "circular import: #{key}"
          end

          @loaded.wait(@lock)
        end
      end
    end

    # A failed load is not cached: the next import, or a thread waiting on
    # this one, tries again.
    def load_entry(key, target)
      value = @loader.call(target)
      @lock.synchronize do
        @values[key] = value
        @gem_usage[key] = target.gem_usage || -> { target.gems }
      end
      value
    ensure
      @lock.synchronize do
        @loading.delete(key)
        @loaded.broadcast
      end
    end

    # A cached Carton keeps the gem versions its first importer gave it: its
    # closure and the locked gems it has loaded, including any loaded lazily
    # since. Raise instead of silently sharing it with an importer that
    # activates or locks another version of one.
    def check_gem_versions(key, target)
      wanted = versions([*target.locked_gems, *target.gems])
      return if wanted.empty?

      usage = @lock.synchronize { @gem_usage.fetch(key) }
      versions(usage.call).each do |name, version|
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
