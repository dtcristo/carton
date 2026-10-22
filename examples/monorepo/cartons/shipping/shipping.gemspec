# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'shipping'
  spec.version = '0.1.0'
  spec.summary = 'Quotes shipping from a carrier API'
  spec.authors = ['Carton']
  spec.files = ['lib/shipping.rb']

  # The runtime gems this Carton uses.
  spec.add_dependency 'carton'
  spec.add_dependency 'faraday'
end
