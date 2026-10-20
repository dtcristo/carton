# frozen_string_literal: true

module LazyDependency
  autoload :Loaded, File.expand_path('lazy_dependency.rb', __dir__)
  def self.load_feature(path)
    require path
  end
end

class String
  def shared_lazy(path)
    require path
    Ruby::Box.current
  end
end
