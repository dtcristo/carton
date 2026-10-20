# frozen_string_literal: true

# Required only by the scratch shop Carton. Replace its namespace references
# and the framework bindings, while retaining the initialized application.
module Shop
  class Application
    def self.reload_domains
      Shop.__send__(:remove_const, :Customers)
      Shop.const_set(:Customers, import('customers'))
      Shop.__send__(:remove_const, :Billing)
      Shop.const_set(:Billing, import('billing'))
      Framework.replace_domains(Customers, Billing)
    end
  end
end
