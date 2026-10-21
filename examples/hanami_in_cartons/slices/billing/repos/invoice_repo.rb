# frozen_string_literal: true

module Billing
  module Repos
    class InvoiceRepo < DB::Repo[:invoices]
      commands :create

      def get(id)
        invoices.by_pk(id).one&.to_h
      end
    end
  end
end
