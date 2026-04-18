# frozen_string_literal: true

require 'leaked_feature/helper'

module LeakedFeature
  def self.status = Helper.status
end

export_default LeakedFeature
