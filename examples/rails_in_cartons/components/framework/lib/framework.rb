# frozen_string_literal: true

require 'carton'

# Rails loads once, in this Carton's Box. Domain Cartons subclass the base
# classes it shares: their own methods run in their Boxes, while inherited Rails
# methods run here, next to Rails and its core extensions.
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'

# Shared base classes for every domain Carton.
require_relative '../app/models/application_record'
require_relative '../app/controllers/application_controller'

module Framework
  ApplicationRecord = ::ApplicationRecord
  ApplicationController = ::ApplicationController
  Rails = ::Rails
  ActiveRecord = ::ActiveRecord

  # Rails finds controllers (`orders#index`) and associations
  # (`belongs_to :customer`) by constant name, and it does that lookup in
  # this Box. Registering a domain's classes defines them here too.
  def self.register(*domains)
    domains.each do |domain|
      domain.constants.each do |name|
        constant = domain.const_get(name)
        Object.const_set(name, constant) if constant.is_a?(Module)
      end
    end
  end
end

export Framework
