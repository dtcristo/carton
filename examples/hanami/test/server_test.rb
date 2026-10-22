# frozen_string_literal: true

require_relative 'cli_helper'
require 'socket'
require 'net/http'
require 'json'
require 'timeout'

class HanamiServerTest < Minitest::Test
  include HanamiCommandSupport

  def test_puma_serves_the_slices_over_http
    Dir.mktmpdir('carton-hanami-server') do |directory|
      exercise_server(directory)
    end
  end

  private

  def exercise_server(directory)
    env = environment(directory, name: 'production')
    hanami(env, 'db', 'migrate')
    port = TCPServer.open('127.0.0.1', 0) { |socket| socket.addr[1] }
    log = File.join(directory, 'puma.log')
    pid =
      Process.spawn(
        env,
        RbConfig.ruby,
        SCRIPT,
        'server',
        '--host=127.0.0.1',
        "--port=#{port}",
        chdir: APP,
        out: log,
        err: %i[child out],
      )
    wait_for_server(port, log)
    http = Net::HTTP.new('127.0.0.1', port, nil)
    http.read_timeout = 10
    malformed =
      http.post('/customers', '{', 'Content-Type' => 'application/json')
    assert_equal '400', malformed.code, malformed.body
    customer = post_json(http, '/customers', customer: { name: 'Ada' })
    invoice =
      post_json(
        http,
        '/invoices.json',
        invoice: {
          customer_id: customer.fetch('id'),
          subtotal_cents: 4200,
        },
      )
    response = http.get("/invoices/#{invoice.fetch('id')}")
    assert_equal '200', response.code
    assert_includes response.body, 'Ada'
    assert_includes response.body, '$46.20'
  ensure
    stop_server(pid) if pid
  end

  def post_json(http, path, attributes)
    response =
      http.post(
        path,
        JSON.generate(attributes),
        'Content-Type' => 'application/json',
      )
    assert_equal '201', response.code, response.body
    JSON.parse(response.body)
  end

  def wait_for_server(port, log)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
    loop do
      Socket.tcp('127.0.0.1', port, connect_timeout: 1, &:close)
      return
    rescue Errno::ECONNREFUSED
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        raise "Puma did not start:\n#{File.read(log)}"
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
