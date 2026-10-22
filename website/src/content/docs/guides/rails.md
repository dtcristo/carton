---
title: Rails
description: Run Customers and Billing as isolated Rails Engines inside Cartons, with domain-owned loaders and a shared framework Carton.
sidebar:
  order: 9
---

The [Rails example](/guides/examples/rails/) runs Customers and Billing as isolated Rails Engines, each in its own Carton. Customers registers a customer; Billing imports Customers, validates an invoice, calculates tax, and persists it. Each domain owns its business classes, controllers, storage records, repositories, routes, views, and migrations.

Rails loads once in a shared framework Carton. A shop Carton mounts both Engines and exports its Rack application to the Main Box. This is an experimental integration with the CLI and reloading limits described below.

<span id="the-shared-application"></span>

## The application

| Request | Behavior |
| --- | --- |
| `POST /customers`, `customer: { name: "Ada" }` | Register a customer and return its ID and trimmed name, status 201 |
| `POST /invoices.json`, `invoice: { customer_id: 1, subtotal_cents: 4200 }` | Issue an invoice and return its values, status 201 |
| `GET /invoices/1.json` | Return the issued invoice, status 200 |
| `GET /invoices/1` | Render its total and escaped customer name as HTML |

Invoice JSON contains `id`, `customer_id`, `subtotal_cents`, `tax_cents`, and `total_cents`. Tax is ten percent, rounded half up using integer cents. A subtotal of 4200 produces tax of 420 and a total of 4620. The stored tax is retained when an invoice is read later.

Blank customer names and invalid subtotals return 422 with domain errors. Subtotals must be non-negative Integers after the controller coerces form strings; fractional and malformed values are rejected. Issuing an invoice for an unknown customer returns 404. Neither Carton holds per-request repositories in module-level state.

<span id="rails-engines"></span>

## Box ownership and loading

Engine namespace isolation alone does not choose a Ruby Box. Each Engine Carton uses its own Zeitwerk loader and configures Rails' main loader to ignore its Ruby application directories. Rails still manages Engine discovery, route files, mounts, templates, and migration tasks. Explicit namespace registration lets framework code resolve qualified record and controller names across the domains.

Domain methods execute beside the Engine's storage models, in the domain's Carton Box; inherited Rails implementations execute in the framework Box. Framework classes and registries remain shared mutable Ruby objects. [Reopening shared classes](/guides/sharing-classes/) still affects their holders.

```sh
cd examples/rails/components/shop
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Use the example's `bin/rails`. It enters the framework Carton before loading Rails commands, and supplies the explicitly exported namespaces to `runner`. Stock Rails/Rake commands, interactive console, generators, and arbitrary third-party Engines are outside that example's verified contract. `SHOP_DATABASE` selects its database; the [example guide](/guides/examples/rails/) lists the commands and layout.

## Testing and development

From the repository root, run the demo and tests:

```sh
bundle exec rake example:rails
```

The tests verify customer/invoice requests, invalid inputs, unknown customers, stored pricing, escaped HTML, associations, and Box ownership under lazy and eager loading. Command tests exercise migrations, routes, runner, and Zeitwerk checks; Puma tests use real HTTP.

Restart after edits. Rails reloading is disabled and Imports stay cached. A separate [reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) uses a scratch copy of the Engine app to investigate two serial reloads; the ordinary example never loads its private hooks.

The app selects its Railties explicitly and adds no runtime patches. Full `rails/all` initialization on Ruby 4.0.7 with Boxes enabled can reach upstream issues through Action Cable and mail dependencies. Jobs, mailers, external workers, and other unrelated Rails features are outside this example. Active Support extensions remain Box-local; domain code that needs them must declare and require them explicitly.
