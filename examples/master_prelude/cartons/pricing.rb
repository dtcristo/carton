# frozen_string_literal: true

# No `require 'active_support'` here: the prelude's core extensions are
# already in this Carton's Box.
module Pricing
  def self.label(name) = name.presence || 'unnamed plan'

  def self.trial_ends(start) = start + 14.days
end

export Pricing
