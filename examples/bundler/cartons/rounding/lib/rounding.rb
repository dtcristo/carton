# frozen_string_literal: true

# This carton has its own Gemfile; activation stays inside this Box.
Carton.setup_bundle

# `import 'bigdecimal'` treats the gem entry file like another carton. It has
# no export, so its top-level constants come back in a `Carton::Namespace`
# instead of becoming top-level here.
BigDecimalCarton = import 'bigdecimal'

export version: BigDecimalCarton::BigDecimal::VERSION
