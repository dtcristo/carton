# frozen_string_literal: true

# Export a callable directly; no wrapper or namespace is added.
export ->(cents) { format('%.2f', cents / 100.0) }
