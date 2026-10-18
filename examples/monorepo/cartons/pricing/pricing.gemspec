# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'pricing'
  spec.version = '0.1.0'
  spec.summary = 'Prices line items with BigDecimal'
  spec.authors = ['Carton']
  spec.files = ['lib/pricing.rb']
  spec.required_ruby_version = '>= 4.0.7'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # The Cartons this one may import.
  spec.add_dependency 'bigdecimal'
  spec.add_dependency 'carton'
end
