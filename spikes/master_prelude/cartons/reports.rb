# frozen_string_literal: true

module Reports
  def self.summary(items)
    items.blank? ? 'nothing to report' : items.to_sentence
  end
end

export Reports
