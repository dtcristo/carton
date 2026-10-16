# frozen_string_literal: true

Carton.setup_bundle(:default)

tool_gem_loadable =
  begin
    require 'tool_gem'
    true
  rescue LoadError
    false
  end

export tool_gem_loadable:
