# frozen_string_literal: true

module Billing
  module Actions
    module Invoices
      class Create < Action
        include Deps['operations.issue_invoice']

        def handle(request, response)
          response.format = :json
          attributes = request.params[:invoice]
          unless attributes.is_a?(Hash)
            halt 400, { errors: { invoice: ['must be an object'] } }.to_json
          end

          case issue_invoice.call(attributes)
          in Success[invoice]
            response.status = 201
            response.body = invoice.to_json
          in Failure[:invalid, errors]
            halt 422, { errors: errors }.to_json
          in Failure[:not_found]
            halt 404
          end
        end
      end
    end
  end
end
