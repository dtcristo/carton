# frozen_string_literal: true

# Ordinary Ruby with no Carton calls. The adapter requires this in its own Box.
PREFIX = 'INV'

def label(number) = "#{PREFIX}-#{number.to_s.rjust(4, '0')}"
