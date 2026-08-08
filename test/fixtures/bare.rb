GREETING = 'hello from bare'
LOOKUP_CALLS = []
NIL_VALUE = nil
FALSE_VALUE = false

def helper
  42
end

def effectful_helper
  LOOKUP_CALLS << :called
end

def lookup_calls
  LOOKUP_CALLS.dup
end

def raises_name_error
  MISSING_FROM_HELPER
end

def raises_no_method_error
  Object.new.missing_from_helper
end
