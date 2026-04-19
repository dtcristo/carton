# frozen_string_literal: true

# Plain cartons stay simple. This one delegates its bundled gem work to a
# transient bundled carton deeper in the tree.
Rounding = import_relative '../../rounding/lib/rounding'

SUMMARY = 'billing stays plain and forwards gem work to rounding'

export summary: SUMMARY, rounding_version: Rounding.fetch(:version)
