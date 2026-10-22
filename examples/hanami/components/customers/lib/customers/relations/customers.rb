# frozen_string_literal: true

module Customers
  module Relations
    class Customers < DB::Relation
      schema :customers, infer: true
    end
  end
end
