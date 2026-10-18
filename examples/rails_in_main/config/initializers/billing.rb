# frozen_string_literal: true

# The billing component is a Carton: it loads once, in its own Box, with the
# gems its gemspec declares at the versions this app's Gemfile.lock pins.
# Only its `export` value crosses back into the Rails app.
Billing = import 'billing'
