# frozen_string_literal: true

module Carton
  # Process-wide record of loaded Cartons, keyed by Entrypoint real path.
  #
  # The Main Box creates one instance and every Carton Box receives that same
  # object, so each Entrypoint loads once no matter which Carton imports it.
  # Ruby objects are shared across Boxes; only definitions are Box-local, so
  # the Main Box's loader builds every Carton Box and the cache keeps it. A
  # plain `Ruby::Box` that requires Carton itself gets its own cache.
  class ImportCache
    # Returned by `claim` when the calling thread should load the Entrypoint.
    LOAD = Object.new.freeze
    private_constant :LOAD

    # `loader` takes a Target with `gems:` and `locked_gems:` and returns the
    # loaded Carton Box, which responds to `export` and `used_gems`.
    def initialize(&loader)
      @loader = loader
      @entries = {}
      # The thread loading each Entrypoint, while it loads.
      @loading = {}
      @lock = Thread::Mutex.new
      @loaded = Thread::ConditionVariable.new
    end

    # The Carton Box for `target`, loaded once per Entrypoint real path.
    #
    # The lock only guards this bookkeeping and is never held while an
    # Entrypoint runs, so an Entrypoint can start threads that import other
    # Cartons. An import of an Entrypoint another thread is loading waits
    # for that load; one the same thread is loading is a cycle. A cycle
    # across threads deadlocks instead, as it does for `require`.
    def import(target, gems: [], locked_gems: nil)
      key = File.realpath(target.feature)
      box = claim(key)
      return load_entry(key, target, gems:, locked_gems:) if box.equal?(LOAD)

      check_gem_versions(key, box, gems:, locked_gems:)
      box
    end

    private

    # The cached Box, or LOAD once this thread owns loading `key`.
    def claim(key)
      @lock.synchronize do
        loop do
          return @entries[key] if @entries.key?(key)

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
    def load_entry(key, target, gems:, locked_gems:)
      box = @loader.call(target, gems:, locked_gems:)
      @lock.synchronize { @entries[key] = box }
      box
    ensure
      @lock.synchronize do
        @loading.delete(key)
        @loaded.broadcast
      end
    end

    # A Shared Import keeps the gem versions its First Importer gave it: its
    # Gem Closure and the locked gems it has loaded, including any loaded lazily
    # since. Raise instead of silently sharing it with an Importer that
    # activates or locks another version of one.
    def check_gem_versions(key, box, gems:, locked_gems:)
      activated = versions(gems)
      wanted = versions(locked_gems).merge(activated)
      return if wanted.empty?

      versions(box.used_gems).each do |name, version|
        next if wanted.fetch(name, version) == version

        verb = activated.key?(name) ? 'activates' : 'locks'
        raise ImportError,
              "#{key} was imported with #{name} #{version}, " \
                "but this import #{verb} #{name} #{wanted[name]}"
      end
    end

    def versions(specs)
      (specs || []).to_h { |spec| [spec.name, spec.version.to_s] }
    end
  end
end
