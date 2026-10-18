Basic = import_relative 'basic'
PI = Basic::PI

def add(...) = Basic.add(...)

def circle_area(radius)
  PI * (radius**2)
end

VERSION = '2.0.0'
