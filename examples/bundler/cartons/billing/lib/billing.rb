# frozen_string_literal: true

# This Carton delegates gem work to an Imported Carton with its own Bundler
# setup deeper in the tree.
Rounding = import_relative '../../rounding'

SUMMARY = 'billing stays plain and forwards gem work to rounding'

# Keywords export a Hash.
export summary: SUMMARY, rounding_version: Rounding[:version]
