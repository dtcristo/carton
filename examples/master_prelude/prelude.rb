# frozen_string_literal: true

# Loaded once into Ruby's Master Box, so every Carton Box created afterwards
# starts with these monkey patches. Keep it to patches and stateless helpers:
# objects created here are shared by every Carton.
require 'active_support'
require 'active_support/core_ext'
