# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../lib/carton'

DIRECTORY = Dir.mktmpdir('carton-hanami-test')
ENV['DATABASE_URL'] = "sqlite://#{DIRECTORY}/shop.sqlite3"
ENV['HANAMI_ENV'] = 'test'

Carton.setup_bundle

require 'minitest/autorun'
require 'rack'
require 'json'

script = File.expand_path('../cartons/shop/bin/hanami', __dir__)
unless system(
         { 'HANAMI_EAGER_LOAD' => 'false' },
         RbConfig.ruby,
         script,
         'db',
         'migrate',
         out: File::NULL,
       )
  abort 'migration failed'
end

module ShopTestBoot
  App = import 'shop'
end

Minitest.after_run do
  ShopTestBoot::App.shutdown
  FileUtils.remove_entry(DIRECTORY)
end
