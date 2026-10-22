# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'pricing'
  spec.version = '0.1.0'
  spec.summary = 'Prices line items with BigDecimal'
  spec.authors = ['Carton']
  spec.files = ['lib/pricing.rb']

  # The runtime gems this Carton uses.
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'carton'
end
