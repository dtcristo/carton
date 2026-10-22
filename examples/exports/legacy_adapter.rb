# frozen_string_literal: true

# Load existing code inside this Carton and explicitly choose its Export.
require_relative 'legacy'

export prefix: PREFIX, label: method(:label)
