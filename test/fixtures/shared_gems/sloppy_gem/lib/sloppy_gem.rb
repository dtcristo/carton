# frozen_string_literal: true

def try_require(name)
  require name
  Gem.loaded_specs[name]&.version&.to_s || 'loaded'
rescue LoadError
  'LoadError'
end

# bigdecimal is locked by the app but undeclared here; minitest is installed
# but not in the app's lockfile.
export locked: try_require('bigdecimal'), unlocked: try_require('minitest')
