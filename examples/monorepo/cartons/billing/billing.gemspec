# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'billing'
  spec.version = '0.1.0'
  spec.summary = 'Builds invoices from priced line items'
  spec.authors = ['Carton']
  spec.files = ['lib/billing.rb']

  # The runtime gems this Carton uses.
  spec.add_dependency 'carton'
  spec.add_dependency 'pricing'
end
