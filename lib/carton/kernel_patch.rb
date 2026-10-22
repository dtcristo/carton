# frozen_string_literal: true

module Carton
  module KernelPatch
    private # like `require` and `require_relative`

    # Import a Carton by absolute path, or by feature name from the Importer's
    # current `$LOAD_PATH`.
    def import(path)
      Runtime.import(path, from: caller_locations(1, 1).first.absolute_path)
    end

    # Import a Carton relative to the calling file, like `require_relative`:
    # relative to the current directory under `ruby -e`, and never from
    # `eval`.
    def import_relative(path)
      location = caller_locations(1, 1).first
      file = location.absolute_path
      base_dir = file ? File.dirname(file) : (Dir.pwd if location.path == '-e')
      raise LoadError, 'cannot infer basepath' unless base_dir

      Runtime.import(path, base_dir:)
    end

    # Export one value from the current Carton; `import` returns it as is.
    # Keywords export a Hash, as in `export version: '1.0'`.
    def export(value)
      file = caller_locations(1, 1).first.absolute_path
      Runtime.export(value, file:)
    end
  end
end

Kernel.prepend(Carton::KernelPatch)
