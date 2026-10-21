# frozen_string_literal: true

module Billing
  module Relations
    class Invoices < DB::Relation
      schema :invoices, infer: true
    end
  end
end
