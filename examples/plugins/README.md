# Plugins example

Two plugins that need incompatible versions of the same gem cannot load into
one Ruby process. This month-end report runner loads both anyway, each in its
own Carton.

## The problem

Each plugin computes money with `bigdecimal`, and each is stuck on a
different major version:

| Plugin | Gemfile | Why it can't move |
| --- | --- | --- |
| `sales_tax` | `bigdecimal ~> 3.1` | calls `BigDecimal#precs`, which 4.0 removed |
| `growth` | `bigdecimal ~> 4.1` | calls `BigMath.cbrt`, which 4.0 added |

Plain Ruby activates one version of a gem per process. Load `sales_tax`
first and `growth` fails:

```
Gem::LoadError: can't activate bigdecimal-4.1.3, already activated bigdecimal-3.3.1
```

Bundler can't help either, since no single lockfile satisfies both
requirements. The usual fixes are to fork one plugin, run each in its own
process, or wait for its maintainer to upgrade.

`sales_tax` also carries a legacy patch that prints every `Float` with two
decimals. In plain Ruby that patch changes `Float#to_s` for the host and for
`growth` too.

## How Carton solves it

`main.rb` finds each directory in `plugins/`, imports it as a Carton, and
calls the two methods of the plugin interface, `title` and `call(orders)`.
Each import runs the plugin in its own `Ruby::Box`:

- Each plugin's Entrypoint calls `Carton.setup_bundle`, which sets up the
  `Gemfile` beside it. `sales_tax` gets bigdecimal 3.3.1 and `growth` gets
  4.1.1, side by side.
- The `Float#to_s` patch stays in `sales_tax`'s Box. `growth` prints `+8.0%`
  and the host prints `0.1 + 0.2` in full.
- The host never loads bigdecimal and has no Gemfile. It only sees the
  module each plugin exports.

```
main.rb                      # the host: finds, imports, and runs plugins
plugins/
  sales_tax/
    Gemfile, Gemfile.lock    # bigdecimal 3.3.1
    lib/sales_tax.rb         # Entrypoint: setup_bundle, export_default SalesTax
    lib/sales_tax/
      float_as_money.rb      # the Float#to_s patch, inside the Carton
  growth/
    Gemfile, Gemfile.lock    # bigdecimal 4.1.1
    lib/growth.rb            # Entrypoint: setup_bundle, export_default Growth
```

Neither plugin knows about the other, and adding a third is a new directory
with its own `Gemfile`.

## Run

```sh
bundle exec rake example:plugins   # installs each plugin's bundle, then runs
RUBY_BOX=1 ruby examples/plugins/main.rb
```

```
== Monthly growth (bigdecimal 4.1.1) ==
2026-06  1000.00
2026-07  1080.00  +8.0%
2026-08  1250.00  +15.7%
2026-09  1331.00  +6.5%
Average +10.0% a month

== Sales tax (bigdecimal 3.3.1) ==
CA  sales 2211.50  tax 160.33
NY  sales 1300.25  tax 52.01
TX  sales 1149.25  tax 71.83
Effective rate 6.10%

== Host ==
BigDecimal defined: false
0.1 + 0.2 = 0.30000000000000004
```

## Sharing a Carton between plugins

A Carton loads once per process, keyed by its Entrypoint's path. If both
plugins import the same third Carton, such as a shared path gem, they get one
copy, built with the gem versions of whichever plugin imported it first. When
the other plugin's bundle locks a different version of a gem that Carton
uses, its import raises `Carton::ImportError`, naming the gem and both
versions, rather than sharing a copy built against the wrong one. Either lock
the same versions in both plugins, or give each plugin its own copy: a
Carton at another path, such as a vendored copy or another installed version
of the gem, is a separate Carton.

## Testing plugins

Test a plugin the way the host uses it: import its directory and call its
interface. Run the test with `RUBY_BOX=1`.

```ruby
# test/growth_test.rb
require 'minitest/autorun'
require 'carton'

class GrowthTest < Minitest::Test
  ORDERS = [{ month: '2026-06', state: 'CA', amount: '100.00' }].freeze

  def test_reports_each_month
    growth = import_relative '../plugins/growth'

    assert_match(/bigdecimal 4\.1\.1/, growth.title)
    assert_equal 2, growth.call(ORDERS).size
  end
end
```

Imports last for the whole process, so a plugin's state carries from one test
to the next. Keep plugins stateless, or run each plugin's tests in its own
process. To test a plugin's internals, require its files directly without
Boxes; see [Testing Cartons](../../docs/usage.md#testing-cartons).

## Limits

- Box is not a security boundary. Plugins run with the host's full
  privileges, so load only plugins you trust.
- Objects are shared, not copied. A plugin can mutate what the host passes
  it, so the host freezes `ORDERS`. Pass plain values such as Strings and
  Hashes: each Box loads its own `BigDecimal` class, so a `BigDecimal` from
  one plugin is not a `BigDecimal` to the host or the other plugin.
- Box isolates patches to builtins such as `Float`. Classes a plugin defines
  are shared, so reopening another plugin's class changes it everywhere; see
  [Sharing classes across Cartons](../../docs/usage.md#sharing-classes-across-cartons).
- `ENV` is process-wide. `setup_bundle` restores it, but load plugins while
  booting, before starting threads that read `ENV`.
- Each Box costs about 70ms to create, plus its own gem loading.
- Carton and `Ruby::Box` are experimental and need Ruby 4.0.7+ with
  `RUBY_BOX=1`.
