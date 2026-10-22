# frozen_string_literal: true

class MethodImporter
  def self.load_add = import_relative('math_tools/basic').method(:add)
end

def load_hash_export = import_relative('hash_export')

export add: MethodImporter.load_add, PI: load_hash_export[:PI]
