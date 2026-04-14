def add(a, b) = a + b
def subtract(a, b) = a - b

export(
  add: method(:add),
  subtract: method(:subtract),
  PI: 3.14159,
  nothing: nil,
  version: '1.0.0',
)
