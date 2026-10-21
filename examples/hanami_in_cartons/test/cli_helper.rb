# frozen_string_literal: true

require_relative '../../../lib/carton'

Carton.setup_bundle

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

module HanamiCommandSupport
  APP = File.expand_path('..', __dir__)
  SCRIPT = File.join(APP, 'bin/hanami')

  def hanami(env, *arguments)
    output, status =
      Open3.capture2e(env, RbConfig.ruby, SCRIPT, *arguments, chdir: APP)
    assert status.success?, "#{arguments.inspect} failed:\n#{output}"
    output
  end

  def environment(directory, name: 'test')
    {
      'RUBY_BOX' => '1',
      'HANAMI_ENV' => name,
      'HANAMI_EAGER_LOAD' => 'false',
      'DATABASE_URL' => "sqlite://#{directory}/shop.sqlite3",
    }
  end
end
