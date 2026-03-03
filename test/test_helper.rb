# frozen_string_literal: true

# Enable Ruby::Box for all tests (checked at C level at startup)
ENV['RUBY_BOX'] ||= '1'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'rb/package'

require 'minitest/autorun'
