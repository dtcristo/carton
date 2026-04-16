# frozen_string_literal: true

module Carton
  module KernelPatch
    def import(path)
      Runtime.import(path, base_dir: Dir.pwd)
    end

    def import_relative(path)
      caller_dir = File.dirname(caller_locations(1, 1).first.path)
      Runtime.import(path, base_dir: caller_dir)
    end

    def export(*args, **kwargs)
      Runtime.export(args, kwargs)
    end

    def export_default(value)
      Runtime.export_default(value)
    end
  end
end

# Inject only the Kernel patch module into Kernel.
::Kernel.prepend(Carton::KernelPatch)
