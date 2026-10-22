# frozen_string_literal: true

# Export: a callable, returned as is; no wrapper or namespace is added.
export ->(cents) { format('%.2f', cents / 100.0) }
