# frozen_string_literal: true

require 'open3'
require 'rbconfig'

# Expected failures stay executable and must reproduce their specific defect.
cases = [
  ['01_method_transplant.rb', [], false, "undefined method 'box'"],
  ['02_builtin_isolation.rb', [], true, 'PASS'],
  ['03_shared_constants.rb', [], true, 'PASS'],
  ['04_modules_and_ancestors.rb', [], true, 'PASS'],
  ['00_discovery.rb', [], true, 'PASS'],
  ['05_active_support.rb', ['--targeted'], true, '"matches":true'],
  ['05_active_support.rb', [], false, '"matches":false'],
  ['05_active_support.rb', ['--extended'], true, '"matches":true'],
  ['06_lazy_loading.rb', [], true, 'VERIFIED FAILURE local require'],
  ['07_multiple_cartons.rb', [], true, 'PASS'],
  [
    '07_multiple_cartons.rb',
    ['--gem'],
    false,
    ['psych/class_loader.rb', 'syntax errors found (SyntaxError)'],
  ],
  ['09_visibility_leak.rb', [], true, 'VERIFIED FAILURE visibility-only'],
  ['10_rails.rb', [], true, 'PASS Rails'],
  [
    '10_rails.rb',
    ['--existing'],
    false,
    ['psych/class_loader.rb', 'syntax errors found (SyntaxError)'],
  ],
  ['11_gem_contract.rb', [], true, 'PASS shared native JSON'],
]
cases.each do |file, args, success, needle|
  output, error, status =
    Open3.capture3(
      { 'RUBY_BOX' => '1' },
      RbConfig.ruby,
      File.join(__dir__, file),
      *args,
    )
  label = ([file] + args).join(' ')
  unless status.success? == success &&
           Array(needle).all? { |text| (output + error).include?(text) }
    abort "UNEXPECTED #{label}\n#{output}\n#{error}"
  end
  puts "#{success ? 'PASS' : 'EXPECTED FAILURE'} #{label}"
end
