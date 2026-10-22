module Advanced
  Basic = import_relative 'basic'
  PI = Basic::PI

  def self.add(...) = Basic.add(...)
  def self.circle_area(radius) = PI * (radius**2)

  VERSION = '2.0.0'
end

export Advanced
