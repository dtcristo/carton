# frozen_string_literal: true

# Requires a Carton-aware library the ordinary way; only this file's export
# should count.
require_relative 'library'

export_default [:entry, Library.name]
