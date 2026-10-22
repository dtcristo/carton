# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class RailsEnginesCommandsTest < Minitest::Test
  APP = File.expand_path('../cartons/shop', __dir__)
  SCRIPT = File.join(APP, 'bin/rails')

  def test_rails_commands_in_fresh_processes
    Dir.mktmpdir('carton-engine-commands') do |directory|
      env = {
        'RUBY_BOX' => '1',
        'RAILS_ENV' => 'test',
        'SHOP_DATABASE' => File.join(directory, 'test.sqlite3'),
      }
      %w[db:prepare db:migrate zeitwerk:check].each do |command|
        rails(env, command)
      end
      assert_includes rails(env, 'routes'), 'customers'
      code = <<~RUBY
        raise unless Rails.application.class.name == 'Shop::Application'
        raise unless Customers.equal?(ShopCLI::Customers)
        puts 'shared'
      RUBY
      assert_includes rails(env, 'runner', code), 'shared'
      %w[false true].each do |eager|
        output = rails(env.merge('RAILS_EAGER_LOAD' => eager), 'test')
        assert_match(/5 (?:runs|tests),/, output)
      end
    end
  end

  private

  def rails(env, *args)
    output, status =
      Open3.capture2e(env, RbConfig.ruby, SCRIPT, *args, chdir: APP)
    assert status.success?, "#{args.inspect} failed:\n#{output}"
    output
  end
end
