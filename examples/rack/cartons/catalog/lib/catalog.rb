# frozen_string_literal: true

# JSON loads in this Carton's Box, not the host's.
require 'json'

# A file inside this Carton: only this Entrypoint can load it.
require_relative 'catalog/products'

module Catalog
  # Hidden from Importers by Ruby's own visibility, which holds across Boxes.
  private_constant :Products

  # Price in cents, or nil for an unknown SKU.
  def self.price(sku) = Products::PRICES[sku]

  # The Rack app: GET /catalog lists every product.
  def self.call(_env)
    [200, { 'content-type' => 'application/json' }, [Products::PRICES.to_json]]
  end
end

# Export: the module is both the Rack app and the Public Surface for other
# Cartons.
export Catalog
