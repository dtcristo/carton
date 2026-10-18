# Dependency injection example

A domain Carton cannot see the application's database models, payment client, or logger by constant name. Pass the objects it needs through ordinary constructor arguments. This checkout Carton calculates an order's total, charges it, saves the payment reference, and logs success. Its host supplies storage, payments, and logging.

```
main.rb                  # Main: sets up the bundle, imports checkout, wires adapters
adapters.rb              # Main: JSON order storage and simulated payments
checkout.rb              # Carton Entrypoint: export Checkout
checkout/service.rb      # Inside the Carton: Checkout::Service
test/checkout_test.rb     # Imports checkout and supplies fakes
test/host_test.rb         # Imports checkout and exercises the file-backed adapters
```

## The boundary

`main.rb` loads the adapters with `require_relative`, then imports `checkout`. The Carton never requires the host or sets up a bundle. Its public interface is a Ruby constructor and a method:

```ruby
Checkout = import_relative 'checkout'
checkout = Checkout::Service.new(orders:, payments:, logger:)
result = checkout.call(order_id: 42)
# => { order_id: 42, total_cents: 3000, payment_id: 'demo-42' }
```

The injected objects need only these methods:

| Object | Method | Result |
| --- | --- | --- |
| `orders` | `fetch(id)` | An order Hash with `:id` and `:items`; each item has integer `:unit_price_cents` and `:quantity` |
| `orders` | `save(order)` | Stores the order with its `:payment_id`; return value is ignored |
| `payments` | `charge(order_id:, amount_cents:)` | A payment ID String, or raises on failure |
| `logger` | `info(message)` | Logs the message; return value is ignored |

These are shared Ruby objects, not copies or remote proxies. Their methods execute in the Box where they were defined, so the host's adapters still resolve `JSON` and `Logger` in Main. The Carton can call the objects it receives without seeing the host's constants. Orders and results use plain Hashes, Arrays, Strings, and Integers, so they need no gem-specific types on either side. The service saves a new Hash instead of mutating the order it fetched.

The demo host stores orders in JSON and records simulated charges in a local file. It creates and removes both files in a temporary directory. No real payments, network, or credentials are involved. A real application would supply its database repository and payment client through the same methods. This example omits payment retries, idempotency, and recovery if saving fails after charging.

If a dependency raises, the exception reaches the caller unchanged. A declined payment does not save the order or log success. Tests define the payment error in Main and rescue it there after it passes through the Carton.

## Tests

The tests import the actual checkout Carton. `checkout_test.rb` supplies fakes and checks totals, adapter calls, and failure behavior without files or a payment provider. `host_test.rb` supplies the demo adapters and checks the stored order, charge, and log output. Neither test needs access to the Carton's internals.

Imports share one module per process, but each `Checkout::Service.new` receives its own dependencies. The Carton keeps no module-level repository, payment client, or logger to reset between tests.

## Run

From the repository root:

```sh
bundle exec rake example:dependency_injection
```

The task installs the example's bundle, runs the host, and runs each test file in its own process. Once the bundle is installed, run the host or tests directly:

```sh
RUBY_BOX=1 ruby examples/dependency_injection/main.rb
RUBY_BOX=1 ruby examples/dependency_injection/test/checkout_test.rb
RUBY_BOX=1 ruby examples/dependency_injection/test/host_test.rb
```

Expected host output:

```text
Paid order 42: 3000 cents
Checkout result: {order_id: 42, total_cents: 3000, payment_id: "demo-42"}
Stored payment: demo-42
Recorded charge: {"id":"demo-42","order_id":42,"amount_cents":3000}
```
