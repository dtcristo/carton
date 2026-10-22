# frozen_string_literal: true

# Load existing code inside this Carton and explicitly choose its Export.
require_relative 'legacy'

# Export: a Hash of the values Importers need, not the legacy constants.
export prefix: PREFIX, label: method(:label)
