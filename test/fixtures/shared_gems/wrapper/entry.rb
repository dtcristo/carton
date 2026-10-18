# frozen_string_literal: true

# A Carton that sets up the app's shared_gems bundle and imports sloppy_gem,
# so sloppy_gem's first import is nested inside this Carton.
Carton.setup_bundle(gemfile: File.expand_path('../Gemfile', __dir__))

export sloppy_gem: import('sloppy_gem')
