# frozen_string_literal: true

# Loaded inside a Carton Box by `Carton::Box#loaded_features`. Like
# `$LOAD_PATH`, `$LOADED_FEATURES` resolves to the Box of the file being
# loaded, so this file sees the Carton's own features even while another
# Carton is importing it.
Carton
  .const_get(:Box)
  .for(Ruby::Box.current)
  .__send__(:receive_loaded_features, $LOADED_FEATURES.to_a)
