# frozen_string_literal: true

# Ordinary Ruby with no Carton calls. Importing it exposes its Entrypoint's
# constants and Helpers through a Namespace.
PREFIX = 'INV'

def label(number) = "#{PREFIX}-#{number.to_s.rjust(4, '0')}"
