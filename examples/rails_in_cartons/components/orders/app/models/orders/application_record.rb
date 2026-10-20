# frozen_string_literal: true

module Orders
  class ApplicationRecord < Framework::ApplicationRecord
    self.abstract_class = true
  end
end
