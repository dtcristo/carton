BARE_LABEL = 'bare'
DECONSTRUCTION_CALLS = []

def helper
  42
end

def effectful_helper
  DECONSTRUCTION_CALLS << :called
  :effect
end
