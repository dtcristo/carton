# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'socket'
require 'tmpdir'
require 'timeout'

class RailsMainServerTest < Minitest::Test
  APP = File.expand_path('..', __dir__)
  SCRIPT = File.join(APP, 'bin/rails')

  def test_puma_serves_the_app_over_http
    Dir.mktmpdir('carton-main-server') do |directory|
      exercise_server(directory)
    end
  end

  private

  def exercise_server(directory)
    env = {
      'RUBY_BOX' => '1',
      'RAILS_ENV' => 'development',
      'MAIN_DATABASE' => File.join(directory, 'server.sqlite3'),
    }
    output, status = Open3.capture2e(env, RbConfig.ruby, SCRIPT, 'db:prepare')
    assert status.success?, output
    output, status =
      Open3.capture2e(
        env,
        RbConfig.ruby,
        SCRIPT,
        'runner',
        'Invoice.create!(id: 1, subtotal_cents: 4200)',
      )
    assert status.success?, output
    port = TCPServer.open('127.0.0.1', 0) { |socket| socket.addr[1] }
    log = File.join(directory, 'puma.log')
    pid =
      Process.spawn(
        env,
        RbConfig.ruby,
        SCRIPT,
        'server',
        '-b',
        '127.0.0.1',
        '-p',
        port.to_s,
        '-P',
        File.join(directory, 'puma.pid'),
        out: log,
        err: %i[child out],
      )
    response = request_when_ready(port)
    assert_match(%r{HTTP/1\.[01] 200}, response)
    assert_includes response, '$46.20'
  ensure
    stop_server(pid) if pid
  end

  def request_when_ready(port)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    loop do
      return(
        Socket.tcp('127.0.0.1', port, connect_timeout: 1) do |socket|
          socket.write("GET /invoices/1 HTTP/1.0\r\nHost: localhost\r\n\r\n")
          Timeout.timeout(10) { socket.read }
        end
      )
    rescue Errno::ECONNREFUSED
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise 'Puma did not start'
      end

      sleep 0.1
    end
  end

  def stop_server(pid)
    Process.kill('TERM', pid)
    Timeout.timeout(10) { Process.waitpid(pid) }
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  rescue Timeout::Error
    Process.kill('KILL', pid)
    Process.waitpid(pid)
  end
end
