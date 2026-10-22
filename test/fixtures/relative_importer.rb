module RelativeImporter
  Sibling = import_relative 'single_export'
  def self.greeting = Sibling.new('World').greet
end

export RelativeImporter
