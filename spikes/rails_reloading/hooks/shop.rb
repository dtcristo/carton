# frozen_string_literal: true

# Required only by the scratch shop Carton. Keep the initialized application
# and its database; replace the domain references at this retained boundary.
class Shop
  def self.reload_domains
    Object.__send__(:remove_const, :Customers)
    Object.const_set(:Customers, import('customers'))
    Object.__send__(:remove_const, :Orders)
    Object.const_set(:Orders, import('orders'))
    Framework.replace_domains(Customers, Orders)
  end
end
