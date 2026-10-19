# frozen_string_literal: true

# Experimental, serial reloads only. This observes private runtime state to
# answer a Rails integration question; it is not a Carton runtime interface.
module ReloadingSpike
  class Imports
    def initialize(reloadable:)
      @reloadable = reloadable.map { |path| File.realpath(path) }
      @importers = Hash.new { |hash, key| hash[key] = [] }
      @entrypoints = {}
      runtime = Carton.const_get(:Runtime)
      @cache = runtime.const_get(:IMPORT_CACHE)
      source = runtime.method(:import).source_location.first
      @trace =
        TracePoint.new(:return) do |event|
          record(event) if event.path == source && event.method_id == :import
        end
      @trace.enable
    end

    # The retained host must explicitly replace the domain references it owns.
    # Eviction alone cannot update Ruby objects already handed to Importers.
    def reload(entrypoint, host:)
      affected = [File.realpath(entrypoint)]
      affected.each do |path|
        @importers[path].each do |importer|
          affected << importer unless affected.include?(importer)
        end
      end
      host_path = @entrypoints.fetch(host)
      unless (affected - @reloadable - [host_path]).empty?
        raise 'reload reaches an unsupported retained Carton'
      end
      unless @cache.instance_variable_get(:@loading).empty?
        raise 'imports are still loading'
      end

      evicted = affected & @reloadable
      evicted.each do |path|
        @cache.instance_variable_get(:@values).delete(path)
        @cache.instance_variable_get(:@gem_usage).delete(path)
      end
      host.reload_domains
      evicted
    end

    def close = @trace.disable

    private

    def record(event)
      target = event.binding.local_variable_get(:target)
      return unless target && File.file?(target.feature)

      path = File.realpath(target.feature)
      @entrypoints[event.return_value] = path
      importer_box = event.binding.local_variable_get(:importer_box)
      importer = Carton.const_get(:Box).for(importer_box)
      from = importer&.instance_variable_get(:@entrypoint)
      @importers[path] |= [from] if from
    end
  end
end
