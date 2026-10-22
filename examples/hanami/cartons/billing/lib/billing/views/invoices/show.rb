# frozen_string_literal: true

module Billing
  module Views
    module Invoices
      class Show < View
        expose :invoice
        expose :customer

        expose :total do |invoice:|
          dollars, cents = invoice.fetch(:total_cents).divmod(100)
          format('$%<dollars>d.%<cents>02d', dollars: dollars, cents: cents)
        end
      end
    end
  end
end
