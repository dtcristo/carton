# frozen_string_literal: true

# Carton boundary: this Entrypoint and everything it loads run in the crm
# plugin's own Box. The host only gets the module exported below.

# A file inside this Carton: only this Entrypoint can load it, and the patch
# it makes applies to this Box only.
require_relative 'crm/float_as_money'

# Carton boundary: the vendored CRM client is a Carton of its own, so this
# plugin needs no Gemfile. crm_client sets up its own bundle, and Faraday
# stays in its Box.
CrmClient = import_relative '../cartons/crm_client'

module Crm
  def self.title = "CRM (faraday #{CrmClient.faraday_version})"

  def self.call(orders)
    orders
      .group_by { it.fetch(:state) }
      .sort
      .map do |state, rows|
        total = rows.sum { it.fetch(:amount) }
        # This Float prints with two decimals because of float_as_money.rb.
        "#{state}  #{total}  #{CrmClient.sync(state, total)}"
      end
  end
end

# Export: the plugin interface is this module's `title` and `call`.
export Crm
