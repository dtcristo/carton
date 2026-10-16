Basic = import_relative 'basic'
PI = Basic::PI

def add(...) = Basic.add(...)

def circle_area(radius)
  PI * (radius**2)
end

export :circle_area, :add, version: '2.0.0'
