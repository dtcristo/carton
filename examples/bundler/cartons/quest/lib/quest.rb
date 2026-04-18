# frozen_string_literal: true

Loot = import_relative '../../loot/lib/loot'

SUMMARY = 'plain carton that delegates to a bundled dependency'

export summary: SUMMARY, bigdecimal_version: Loot.fetch(:bigdecimal_version)
