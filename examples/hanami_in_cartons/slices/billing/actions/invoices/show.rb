# frozen_string_literal: true

module Billing
  module Actions
    module Invoices
      class Show < Action
        include Deps['repos.invoice_repo', 'customer_directory']

        params { required(:id).filled(:integer, gt?: 0) }
        def handle(request, response)
          halt 422 unless request.params.valid?
          row = invoice_repo.get(request.params[:id])
          halt 404 unless row
          invoice = Invoice.new(**row).to_h
          if request.env.fetch('PATH_INFO').end_with?('.json')
            response.format = :json
            response.body = invoice.to_json
          else
            customer = customer_directory.find(invoice.fetch(:customer_id))
            halt 404 if customer.failure?
            response.render(view, invoice: invoice, customer: customer.value!)
          end
        end
      end
    end
  end
end
