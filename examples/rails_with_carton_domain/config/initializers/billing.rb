# frozen_string_literal: true

# Rake also defines a top-level import. The app's own namespace avoids it.
module Shop
  Billing = import 'billing'
  Customers = import 'customers' # The same Shared Import Billing already uses.
end
