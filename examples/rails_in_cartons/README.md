# Rails in Cartons example

A Rails API app built from Cartons, with Rails loaded once and nothing
Rails-related in the Main Box:

| Carton | Box contains | Exports |
| --- | --- | --- |
| `framework` | Rails, Active Record, Action Controller, sqlite3 | `ApplicationRecord`, `ApplicationController`, `register`, `Rails`, `ActiveRecord` |
| `customers` | `Customer` model, `CustomersController` | those classes, `create_schema` |
| `orders` | `Order` model, `OrdersController`; imports `customers` | those classes, `create_schema` |
| `shop` | the `Rails::Application`, routes, `config/database.yml` | `export_default Shop` |

`main.rb` plays the server: the Main Box loads only Rack, imports `shop`, and
sends requests to it.

```
main.rb                          # Main Box: Rack only; Shop = import 'shop'
components/
  framework/lib/framework.rb     # require 'rails' ... once
  framework/app/{models,controllers}/application_*.rb
  customers/lib/customers.rb     # imports framework; Zeitwerk for app/
  customers/app/models/customer.rb
  customers/app/controllers/customers_controller.rb
  orders/...                     # same shape; imports customers too
  shop/lib/shop.rb               # class Shop < Rails::Application; routes
  shop/config/database.yml
```

## How it works

- **Subclassing across Boxes.** `class Order < ApplicationRecord` runs in the
  orders Box, but `ApplicationRecord` is the framework's class object. Ruby
  objects are shared between Boxes, and a method runs in the Box that defined
  it: `Order`'s own code runs in the orders Box, and inherited Active Record
  methods (`belongs_to`, `find`, `render`, `as_json`) run in the framework Box
  next to Rails. So Rails is loaded once, not once per domain.
- **Name lookups need registering.** Rails resolves routes (`orders#index`)
  and associations (`belongs_to :customer`) by constant name, inside the
  framework Box. `Framework.register(Customers, Orders)` defines the domains'
  exported classes there with `Object.const_set`.
- **Domains keep Rails conventions.** Each has `app/models` and
  `app/controllers`, autoloaded by its own Zeitwerk loader in its own Box,
  and owns its tables through `create_schema`.
- **Domains depend on each other through imports.** `orders` imports
  `customers` and gets the same `Customer` class Rails sees.

## Limits

- **Core extensions are per Box.** Domain code does not see Active Support's
  core extensions (`blank?`, `1.day`, ...), because they are monkey patches in
  the framework Box. A domain that wants some can `require` them, for example
  `require 'active_support/core_ext/object/blank'`, which loads just that part
  in its Box.
- **Shared classes are shared definitions.** `ApplicationRecord` and every
  domain class are ordinary classes created in a Carton Box, so they have one
  definition. A Carton that reopens `ApplicationRecord` (or another domain's
  model) changes it for every Carton. Only patches to builtin classes such as
  `String` stay in the Box that makes them. To avoid it, a domain can subclass
  its own `ApplicationRecord < Framework::ApplicationRecord` (with
  `self.abstract_class = true`) instead of binding the shared one, and refine
  rather than reopen another domain's classes. Freezing these classes is not
  an option: Active Record writes class-level state at runtime. See
  [Sharing classes across cartons](../../docs/usage.md#sharing-classes-across-cartons).
- **Everything Rails needs by name must be registered.** That includes
  controllers, models, and anything else Rails constantizes, such as
  serializers or polymorphic types.
- **No reloading.** Cartons load once per process, so restart after changes.
- **No Rails CLI.** Generators, `rails console`, and migrations are not wired
  up; each domain creates its own tables at boot.

Compare with [examples/rails_in_main](../rails_in_main/README.md), which keeps
Rails in the Main Box and puts only plain-Ruby domain logic in a Carton.

## Run

```sh
RUBY_BOX=1 ruby examples/rails_in_cartons/main.rb
```
