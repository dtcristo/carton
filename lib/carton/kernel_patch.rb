# frozen_string_literal: true

module Carton
  module KernelPatch
    # Import a carton by absolute path or by feature name from the caller box's
    # current `$LOAD_PATH`.
    def import(path)
      Runtime.import(path, base_dir: Dir.pwd)
    end

    # Import a carton relative to the calling file, like `require_relative`.
    def import_relative(path)
      caller_dir = File.dirname(caller_locations(1, 1).first.path)
      Runtime.import(path, base_dir: caller_dir)
    end

    # Export a small named API from the current carton.
    def export(*args, **kwargs)
      Runtime.export(args, kwargs)
    end

    # Export a single default value from the current carton.
    def export_default(value)
      Runtime.export_default(value)
    end
  end
end

# Inject only the Kernel patch module into Kernel.
Kernel.prepend(Carton::KernelPatch)
