---
title: Sharing classes and services
description: What crosses a Carton boundary by reference, how to avoid reopening shared classes, and how to pass application services in.
sidebar:
  order: 5
---

Boxes isolate monkey patches to builtin classes: patching `String` in one Carton does not change `String` anywhere else. The exception is a [Ruby 4.0.7 bug](/start/status/#before-production): changing only a builtin method's visibility leaks to every Box. Classes a Carton defines are different. An exported class is one object with one definition, shared by every Importer, as in ordinary Ruby. Reopening it from another Carton, including `class Customer` in a Box where `Customer` names the imported class, changes it for every Carton.

Box is not a security boundary, so this cannot be prevented outright. These habits prevent accidental reopening.

`carton check` warns about class/module definitions that open a directly imported value or a constant beneath it, such as `class Billing::Invoice`. This is a static warning, not a runtime guard: aliases and dynamic mutation through `class_eval` or `define_method` are not followed. Subclassing does not warn.

## Subclass instead of reopening

Give each Carton its own base classes rather than binding a shared one to a bare name:

```ruby
# customers/lib/customers.rb
class ApplicationRecord < Framework::ApplicationRecord # this Carton's own class
  self.abstract_class = true
end
```

Changes to a subclass never reach its parent.

## Refine to extend another Carton's class

A refinement applies only to files that activate it with `using`, so the owning Carton never sees it:

```ruby
# shop.rb
module Discounts
  refine Billing::Invoice do
    def discounted(rate) = total * (1 - rate)
  end
end

using Discounts # only this file sees Invoice#discounted
```

## Freeze plain-Ruby exports

`export Pricing.freeze` makes any reopen raise `FrozenError` while still allowing subclasses. Do not freeze Active Record models or their base classes: Rails writes class-level state at runtime, so even `create!` raises once a model's class is frozen.

[How Boxes work](https://github.com/dtcristo/carton/blob/main/docs/internals/how-boxes-work.md#which-classes-get-per-box-copies-ruby-407) explains why only builtin classes get a copy per Box.

## Passing application services

A Carton cannot see the application's constants, but it can call objects the application passes in. Use ordinary constructor arguments to supply a repository, payment client, or logger:

```ruby
# main.rb
Checkout = import_relative 'checkout'
checkout = Checkout::Service.new(orders:, payments:, logger:)
checkout.call(order_id: 42)
```

An injected object's methods run in the Box where they were defined, with that Box's constants and gems. The Carton needs only the methods it calls, so tests can pass fakes through the same interface. Objects are shared, not copied; keep per-instance dependencies on instances instead of the shared exported module. Prefer plain values for inputs and results when each side loads its own gem classes.

The [Dependency injection example](/guides/examples/dependency-injection/) runs this checkout with file-backed adapters and tests it through its export with fakes.
