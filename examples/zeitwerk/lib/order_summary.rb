# frozen_string_literal: true

# The app's own code, not a Carton: main.rb's Zeitwerk loader autoloads it in
# the Main Box. Billing and Shipping are the constants main.rb bound to the
# imported Cartons.
class OrderSummary
  def self.line(cents, kilograms)
    shipping = format('$%.2f', Shipping::Rate.quote(kilograms) / 100.0)
    "#{Billing.invoice(cents)} + shipping #{shipping}"
  end
end
