# frozen_string_literal: true

module Carton
  # Base class for every error Carton raises itself. A missing Import target
  # raises `LoadError`, as `require` does.
  class Error < StandardError
  end

  # An Import that cannot go ahead: Boxes are disabled, the target is an
  # Interior file or not Ruby source, a Carton imports itself, or a Shared
  # Import was built against other gem versions.
  class ImportError < Error
  end

  # An Entrypoint finished without exporting, called `export` twice, or
  # gave it a Symbol.
  class ExportError < Error
  end

  # Raised when Carton cannot find the bundle file for `setup_bundle`.
  class GemfileNotFound < Error
  end

  # The error classes every Carton Box shares with the Main Box.
  ERRORS = %i[Error ImportError ExportError GemfileNotFound].freeze
  private_constant :ERRORS
end
