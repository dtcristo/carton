# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require 'json'
shared =
  SharedGemsPrototype.new(
    gemfile: File.expand_path('Gemfile', __dir__),
    extra_builtins:
      ARGV.include?('--extended') ? %w[Enumerable Range Float Regexp] : [],
  )
features =
  (
    if ARGV.include?('--targeted')
      %w[
        active_support
        active_support/core_ext/object/blank
        active_support/core_ext/integer/time
      ]
    else
      %w[active_support active_support/core_ext]
    end
  )
shared.load(*features)
control =
  SharedGemsPrototype.new(gemfile: File.expand_path('Gemfile', __dir__)).box
features.each { |feature| control.require(feature) }
checks = {
  blank: '"".blank?',
  present: '"hello".present?',
  nil_blank: 'nil.blank?',
  days: '14.days.to_i',
  sentence: '["a", "b", "c"].to_sentence',
  duration: '2.days.parts',
  time: 'Time.utc(2026, 1, 2).beginning_of_day.to_i',
  date: 'Date.new(2026, 1, 2).next_week.to_s',
  inflection: '"shared_gems".camelize',
  hash: '{a: {b: 1}}.deep_stringify_keys',
  array: '[nil, "", "x"].compact_blank',
  exception:
    'begin; [1].to_sentence(unknown: true); rescue ArgumentError => e; [e.class.name, e.message]; end',
  domain:
    'class Invoice; def valid_name?(name) = name.present?; end; Invoice.new.valid_name?("yes")',
  native: 'BigDecimal("1.5").to_s',
  lazy: 'ActiveSupport::Inflector.transliterate("café")',
}
if ARGV.include?('--targeted')
  checks = checks.slice(:blank, :present, :nil_blank, :days, :duration, :domain)
end
expected_results =
  checks.transform_values do |code|
    [:ok, control.eval(code)]
  rescue StandardError, LoadError => e
    [:error, e.class.name, e.message.lines.first.strip]
  end
report = {}
2.times do |i|
  child = shared.create_box
  checks.each do |name, code|
    expected = expected_results.fetch(name)
    actual =
      begin
        [:ok, child.eval(code)]
      rescue StandardError, LoadError => e
        [:error, e.class.name, e.message.lines.first.strip]
      end
    report[name] = {
      control: expected,
      child: actual,
      matches: expected == actual,
    }
  end
  equal(false, child.eval('Gem.loaded_specs.key?("activesupport")'))
  equal(shared.box, child.eval('"".method(:blank?).box'))
  assert(
    child.const_get(:ActiveSupport).equal?(
      shared.box.const_get(:ActiveSupport),
    ),
  )
  child.eval("load #{File.expand_path('fixtures/observe.rb', __dir__).inspect}")
  assert(
    child
      .instance_variable_get(:@spike_features)
      .none? do |f|
        f.include?('/active_support/') || f.end_with?('/active_support.rb')
      end,
  )
  puts JSON.generate(child: i, checks: report)
end
puts JSON.pretty_generate(
       manifest:
         shared.summary.reject do |entry|
           entry.values_at(
             :methods,
             :visibility,
             :remove,
             :ambiguous_removals,
             :undef,
             :includes,
             :prepends,
             :unsupported,
           ).all?(&:empty?)
         end,
       shared_constants: shared.constants.keys,
     )
equal(false, ''.respond_to?(:blank?))
equal(false, Ruby::Box.master.eval('String.method_defined?(:blank?)'))
# A mismatch is evidence, not silently reclassified as success.
exit(report.values.all? { |result| result[:matches] } ? 0 : 1)
