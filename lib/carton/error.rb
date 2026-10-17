# frozen_string_literal: true

module Carton
  # Base class for every error Carton raises itself. A missing Import target
  # raises `LoadError`, as `require` does, and a missing exported name raises
  # `NameError`.
  class Error < StandardError
  end

  # An Import that cannot go ahead: Boxes are disabled, a Carton imports
  # itself, or a cached Carton was built against other gem versions.
  class ImportError < Error
  end

  # An Export Declaration that breaks the rules: a name exported twice,
  # `export_default` called twice, or both forms in one Entrypoint.
  class ExportError < Error
  end

  # Raised when Carton cannot find the bundle file for `setup_bundle`.
  class GemfileNotFound < Error
  end
end
