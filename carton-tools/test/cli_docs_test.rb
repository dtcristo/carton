# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# The CLI reference on the website quotes each usage the command prints, so
# a new or changed option fails here until its page is updated.
class CliDocsTest < Minitest::Test
  PAGES =
    File.expand_path('../../website/src/content/docs/reference/cli', __dir__)

  def test_overview_quotes_the_usage
    assert_quoted usage('--help'), 'index.md'
  end

  def test_each_command_page_quotes_its_usage
    %w[check rbs].each do |command|
      assert_quoted usage(command), "#{command}.md"
    end
  end

  def test_each_option_has_a_row_in_its_command_page
    %w[check rbs].each do |command|
      page = File.read(File.join(PAGES, "#{command}.md"))
      usage(command)
        .scan(/--[a-z-]+/)
        .each do |option|
          assert_match(
            /^\| .*`#{option}/,
            page,
            "#{command}.md lacks #{option}",
          )
        end
    end
  end

  private

  # `--help` prints to stdout; a command without PATH prints its usage to
  # stderr.
  def usage(*argv)
    out = StringIO.new
    Carton::Tools::CLI.start(argv, out:, err: out)
    out.string
  end

  def assert_quoted(usage, page)
    assert_includes File.read(File.join(PAGES, page)), usage.strip, page
  end
end
