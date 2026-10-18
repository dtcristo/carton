# frozen_string_literal: true

# Carton boundary: this Entrypoint and everything it loads run in the
# sales_tax plugin's own Box. The host only gets the module exported below.

# Bundle boundary: plugins/sales_tax/Gemfile locks bigdecimal 3.3.1. Bundler
# activates it in this Box only, so the host and other plugins never see it.
Carton.setup_bundle
require 'bigdecimal'

# A file inside this Carton: only this Entrypoint can load it, and the patch
# it makes applies to this Box only.
require_relative 'sales_tax/float_as_money'

module SalesTax
  RATES = { 'CA' => '0.0725', 'NY' => '0.04', 'TX' => '0.0625' }.freeze

  def self.title = "Sales tax (bigdecimal #{BigDecimal::VERSION})"

  def self.call(orders)
    lines = []
    tax = BigDecimal(0)
    orders
      .group_by { |order| order.fetch(:state) }
      .sort
      .each do |state, rows|
        state_sales = total(rows)
        state_tax = (state_sales * BigDecimal(RATES.fetch(state))).round(2)
        tax += state_tax
        lines << "#{state}  sales #{money(state_sales)}  tax #{money(state_tax)}"
      end

    # This Float prints with two decimals because of float_as_money.rb.
    lines << "Effective rate #{(tax / total(orders) * 100).to_f}%"
  end

  def self.total(orders)
    orders.sum(BigDecimal(0)) { |order| amount(order.fetch(:amount)) }
  end

  # Written against bigdecimal 3. BigDecimal#precs was removed in 4.0, so
  # this plugin cannot move to the version the growth plugin needs.
  def self.amount(string)
    amount = BigDecimal(string)
    digits, = amount.precs
    raise ArgumentError, "#{string} has too many digits" if digits > 36

    amount
  end

  def self.money(amount) = format('%.2f', amount)

  private_class_method :total, :amount, :money
end

# Export boundary: the plugin interface is this module's `title` and `call`.
export SalesTax
