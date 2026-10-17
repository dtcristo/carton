# frozen_string_literal: true

# A Carton whose own bundle locks a bigdecimal that sloppy_gem uses without
# declaring it.
Carton.setup_bundle

export sloppy_gem: import('sloppy_gem')
