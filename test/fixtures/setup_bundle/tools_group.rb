# frozen_string_literal: true

Carton.setup_bundle(:tools)

# Bundler.require runs after setup_bundle has restored ENV, so it must rely on
# the Gemfile Bundler already selected.
Bundler.require(:tools)

export tool_gem_version: ToolGem::VERSION,
       root: Bundler.root.to_s,
       env_gemfile: ENV['BUNDLE_GEMFILE']
