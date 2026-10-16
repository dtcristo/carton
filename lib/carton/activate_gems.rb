# frozen_string_literal: true

# Required inside a Carton Box by `Carton::Box#activate_gems`. `$LOAD_PATH`
# resolves to the Box of the file being loaded, so activating from a file
# required here updates this Box even during a nested Import.
Carton.const_get(:GemActivation).activate(
  *Ruby::Box.current.__send__(:pending_gems),
)
