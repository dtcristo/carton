# frozen_string_literal: true

require_relative '../../../support/package_support'

ComplexExample::PackageSupport.add_sibling_package_libs(__dir__)

require 'loot/item'

# Cross-package import by name (quest lib is on $LOAD_PATH)
Quests = import('quest')

module Loot
  LIST_SEPARATOR = '|'

  DOTENV_PAYLOAD =
    ComplexExample::PackageSupport.load_dotenv_payload(
      package_root: File.expand_path('..', __dir__),
      env_file: File.expand_path('../.env', __dir__),
    )

  CONFIG = DOTENV_PAYLOAD.fetch('config')
  DOTENV_VERSION = DOTENV_PAYLOAD.fetch('version')

  KITS_BY_TIER = {
    common: CONFIG.fetch('COMMON_KITS', '').split(LIST_SEPARATOR),
    uncommon: CONFIG.fetch('UNCOMMON_KITS', '').split(LIST_SEPARATOR),
    rare: CONFIG.fetch('RARE_KITS', '').split(LIST_SEPARATOR),
    epic: CONFIG.fetch('EPIC_KITS', '').split(LIST_SEPARATOR),
  }.freeze

  def self.suggest_kit(difficulty: :medium, weather: :clear)
    tier =
      case difficulty
      when :easy
        :common
      when :medium
        :uncommon
      when :hard
        :rare
      when :legendary
        :epic
      else
        :common
      end

    weather_key = "WEATHER_#{weather.to_s.upcase}"
    weather_boost =
      CONFIG.fetch(
        weather_key,
        CONFIG.fetch('WEATHER_DEFAULT', 'Spare batteries'),
      )
    planner_name = Quests.fetch(:planner_name)

    Item.random(
      tier:,
      weather:,
      weather_boost:,
      planner_name:,
      kits_by_tier: KITS_BY_TIER,
    )
  end
end

export(
  Loot:,
  suggest_kit: Loot.method(:suggest_kit),
  VERSION: '0.2.0',
  DOTENV_VERSION: Loot::DOTENV_VERSION,
)
