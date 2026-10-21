# frozen_string_literal: true

module Customers
  module Actions
    module Customers
      class Create < Action
        include Deps['operations.register_customer']

        def handle(request, response)
          response.format = :json
          attributes = request.params[:customer]
          unless attributes.is_a?(Hash)
            halt 400, { errors: { customer: ['must be an object'] } }.to_json
          end

          case register_customer.call(attributes)
          in Success[customer]
            response.status = 201
            response.body = customer.to_json
          in Failure[:invalid, errors]
            halt 422, { errors: errors }.to_json
          end
        end
      end
    end
  end
end
