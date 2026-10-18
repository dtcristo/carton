# frozen_string_literal: true

# Each Carton Box loads its own Carton, but every Box shares one set of error
# classes, so a Carton can rescue what a Carton it imports raises.
begin
  import_relative 'repeated_export'
rescue Carton::ExportError => e
  export e.class
end
