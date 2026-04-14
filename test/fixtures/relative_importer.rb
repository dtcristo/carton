Sibling = import_relative 'single_export'

export greeting: -> { Sibling.new('World').greet }
