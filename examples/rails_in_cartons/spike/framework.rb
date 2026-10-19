# frozen_string_literal: true

# Required only by the scratch framework Carton, so Object here is the
# framework Box's Object, where Rails resolves controller and model names.
module Framework
  def self.replace_domains(*domains)
    domains.each do |domain|
      domain
        .constants(false)
        .each do |name|
          constant = domain.const_get(name, false)
          next unless constant.is_a?(Module)

          if Object.const_defined?(name, false)
            Object.__send__(:remove_const, name)
          end
          Object.const_set(name, constant)
        end
    end
  end
end
