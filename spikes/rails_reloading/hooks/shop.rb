# frozen_string_literal: true

# Required only by the scratch shop Carton. Replace its namespace references
# and the framework bindings, while retaining the initialized application.
module Shop
  class Application
    def self.reload_domains
      Shop.__send__(:remove_const, :Customers)
      Shop.const_set(:Customers, import('customers'))
      Shop.__send__(:remove_const, :Orders)
      Shop.const_set(:Orders, import('orders'))
      Framework.replace_domains(Customers, Orders)
    end
  end
end
