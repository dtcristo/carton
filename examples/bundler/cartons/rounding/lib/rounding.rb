# frozen_string_literal: true

# This Carton has its own Gemfile; activation stays inside this Box.
Carton.setup_bundle

# `import 'bigdecimal'` treats the gem Entrypoint like another Carton. It has
# no export, so its top-level constants come back in a `Carton::Namespace`
# instead of becoming top-level here.
BigDecimalCarton = import 'bigdecimal'

export version: BigDecimalCarton::BigDecimal::VERSION
