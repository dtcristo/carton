# frozen_string_literal: true

module Carton
  module KernelPatch
    private # like `require` and `require_relative`

    # Import a carton by absolute path or by feature name from the caller box's
    # current `$LOAD_PATH`.
    def import(path)
      Runtime.import(path)
    end

    # Import a carton relative to the calling file, like `require_relative`.
    def import_relative(path)
      caller_dir = File.dirname(caller_locations(1, 1).first.path)
      Runtime.import(path, base_dir: caller_dir)
    end

    # Export top-level methods by name plus keyword values from the current
    # carton. `self` is the carton's top-level object, which owns its methods.
    def export(*names, **values)
      file = caller_locations(1, 1).first.absolute_path
      Runtime.export(names, values, owner: self, file:)
    end

    # Export a single default value from the current carton.
    def export_default(value)
      file = caller_locations(1, 1).first.absolute_path
      Runtime.export_default(value, file:)
    end
  end
end

# Inject only the Kernel patch module into Kernel.
Kernel.prepend(Carton::KernelPatch)
