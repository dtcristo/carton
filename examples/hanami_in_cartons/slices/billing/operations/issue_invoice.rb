# frozen_string_literal: true

module Billing
  module Operations
    class IssueInvoice < Operation
      include(
        Deps['contracts.invoice', 'repos.invoice_repo', 'customer_directory'],
      )

      def call(attributes)
        validation = invoice.call(attributes)
        unless validation.success?
          step Failure[:invalid, validation.errors.to_h]
        end
        attributes = validation.to_h
        step customer_directory.find(attributes.fetch(:customer_id))
        row =
          invoice_repo.create(
            **attributes,
            tax_cents: TaxPolicy.call(attributes.fetch(:subtotal_cents)),
          )
        Invoice.new(**row.to_h).to_h
      end
    end
  end
end
