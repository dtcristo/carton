# frozen_string_literal: true

Challenge = import_relative 'quest/challenge'

FEATURES = [
  'single exports',
  'named exports',
  'import by name',
  'import_relative inside a package',
].freeze
SUMMARY = 'plain package loaded by name'
CHALLENGE_SUMMARY = Challenge.summary

export FEATURES:, summary: SUMMARY, challenge_summary: CHALLENGE_SUMMARY
