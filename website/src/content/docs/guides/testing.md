---
title: Testing
description: Test a Carton through its export in integration tests, and reach its private code with plain require in unit tests.
sidebar:
  order: 6
---

A Carton has two kinds of test. An integration test imports the Carton and sees only its Public Surface. A unit test loads the Carton's files with plain `require` and can reach its private code.

## Integration tests

Tests run in the Main Box, so a test imports a Carton the same way an app does. Run them with `RUBY_BOX=1`.

```ruby
require 'minitest/autorun'
require 'carton'

class MathTest < Minitest::Test
  def setup
    @math = import_relative '../lib/math' # the Carton's export, nothing more
  end

  def test_add
    assert_equal 5, @math.add(2, 3)
  end
end
```

- Imports are shared across the process, so a Carton's state persists from one test to the next. Keep Cartons stateless, or reset their state through their Public Surface.
- Files inside a Carton cannot be imported on their own, and private constants stay private across the boundary.

## Unit tests

A Carton's files are ordinary Ruby. Outside an import, `export` declares nothing, so `require` loads an Entrypoint into the test's own Box like any other file. A unit test can then test code the Carton keeps private, and needs no `RUBY_BOX=1`:

```ruby
require 'carton' # defines export, which does nothing here
require 'minitest/autorun'
require 'pricing' # plain require: no import, no boundary

class PricingTest < Minitest::Test
  # Pricing::Rounding raises NameError; const_get still returns it.
  Rounding = Pricing.const_get(:Rounding)

  def test_cents
    assert_equal BigDecimal('1.01'), Rounding.cents(BigDecimal('1.005'))
  end
end
```

- Keep unit and integration tests in separate files, and run each file in its own process. A plain `require` loads a Second Copy of the Carton beside the imported one. For example, with two Rake tasks:

  ```ruby title="Rakefile"
  task 'test:unit' do
    Dir['test/unit/**/*_test.rb'].each { |file| ruby '-Ilib', file } # no Boxes
  end

  task 'test:integration' do
    Dir['test/integration/**/*_test.rb'].each do |file|
      sh({ 'RUBY_BOX' => '1' }, 'ruby', '-Ilib', file)
    end
  end

  task test: %w[test:unit test:integration]
  ```

- Private code can stay private instead of moving into a Carton of its own. A test names it once with `const_get`, or `send` for a private method, so each reach into private code is easy to find.

The [monorepo example's tests](/guides/examples/monorepo/#tests) have both kinds, run under the monorepo's bundle.
