# frozen_string_literal: true

module SyntheticDependency
  VALUE = 'shared'
end

class String
  def shared_synthetic = SyntheticDependency::VALUE
end
