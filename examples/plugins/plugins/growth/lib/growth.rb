# frozen_string_literal: true

# Carton boundary: this Entrypoint and everything it loads run in the growth
# plugin's own Box. The host only gets the module exported below.

# Bundle boundary: plugins/growth/Gemfile locks bigdecimal 4.1.1. Bundler
# activates it in this Box only, beside sales_tax's 3.3.1.
Carton.setup_bundle
require 'bigdecimal'
require 'bigdecimal/math'

module Growth
  def self.title = "Monthly growth (bigdecimal #{BigDecimal::VERSION})"

  def self.call(orders)
    totals =
      orders
        .group_by { |order| order.fetch(:month) }
        .sort
        .map do |month, month_orders|
          [
            month,
            month_orders.sum(BigDecimal(0)) { BigDecimal(it.fetch(:amount)) },
          ]
        end

    lines =
      totals.each_with_index.map do |(month, total), index|
        line = "#{month}  #{format('%.2f', total)}"
        next line if index.zero?

        # sales_tax's Float#to_s patch does not reach this Box, so these
        # Floats print as plain Ruby prints them.
        "#{line}  #{percent(total / totals[index - 1][1])}"
      end

    # Four months are three steps, so the average rate is a cube root.
    # BigMath.cbrt is new in bigdecimal 4, so this plugin cannot run on the
    # 3.3.1 that sales_tax needs.
    quarter = totals.last[1] / totals.first[1]
    lines << "Average #{percent(BigMath.cbrt(quarter, 20))} a month"
  end

  def self.percent(ratio)
    change = ((ratio - 1) * 100).round(1).to_f
    "#{'+' if change.positive?}#{change}%"
  end

  private_class_method :percent
end

# Export boundary: the plugin interface is this module's `title` and `call`.
export_default Growth
