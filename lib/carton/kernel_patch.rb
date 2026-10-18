# frozen_string_literal: true

module Carton
  module KernelPatch
    private # like `require` and `require_relative`

    # Import a Carton by absolute path, or by feature name from the Importer's
    # current `$LOAD_PATH`.
    def import(path)
      Runtime.import(path, from: caller_locations(1, 1).first.path)
    end

    # Import a Carton relative to the calling file, like `require_relative`.
    def import_relative(path)
      caller_dir = File.dirname(caller_locations(1, 1).first.path)
      Runtime.import(path, base_dir: caller_dir)
    end

    # Export one value from the current Carton; `import` returns it as is.
    # Keywords export a Hash, as in `export version: '1.0'`.
    def export(value)
      file = caller_locations(1, 1).first.absolute_path
      Runtime.export(value, file:)
    end
  end
end

# Inject only the Kernel patch module into Kernel.
Kernel.prepend(Carton::KernelPatch)
