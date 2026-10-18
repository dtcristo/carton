# frozen_string_literal: true

# This Carton Bundle uses its own Gemfile; activation stays in the Carton Box.
Carton.setup_bundle

# `import 'bigdecimal'` treats the gem Entrypoint like another Carton. It has
# no Export, so its top-level constants come back in a Namespace
# instead of becoming top-level here.
BigDecimalCarton = import 'bigdecimal'

export version: BigDecimalCarton::BigDecimal::VERSION
