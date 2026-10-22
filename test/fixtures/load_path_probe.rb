# frozen_string_literal: true

module LoadPathProbe
  LOAD_PATH_AT_LOAD = $LOAD_PATH.to_a.freeze
end

export LoadPathProbe
