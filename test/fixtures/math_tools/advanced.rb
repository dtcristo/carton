import_relative('basic') => { add:, PI: pi }
PI = pi

def circle_area(radius)
  PI * (radius**2)
end

export circle_area: method(:circle_area), add:, version: '2.0.0'
