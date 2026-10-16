# frozen_string_literal: true

# A Carton whose own bundle locks a different bigdecimal than the app's.
Carton.setup_bundle

export priced_gem: import('priced_gem')
