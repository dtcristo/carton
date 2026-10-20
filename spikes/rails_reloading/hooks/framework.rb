# frozen_string_literal: true

# Required only by the scratch framework Carton, so Object here is the
# framework Box's Object, where Rails resolves controller and model names.
module Framework
  def self.replace_domains(*domains)
    domains.each do |domain|
      name = domain.name
      Object.__send__(:remove_const, name) if Object.const_defined?(name, false)
      Object.const_set(name, domain)
    end
  end
end
