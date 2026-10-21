# frozen_string_literal: true

module Billing
  class Slice < Hanami::Slice
    config.root = File.expand_path('..', __dir__)
  end
end
