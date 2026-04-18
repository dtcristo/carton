# Gem example

Minimal gem project showing how a gem can `require 'carton'`, bootstrap its own bundle inside the box, and export a tiny public API.

The gem itself lives in `lib/gem_in_carton.rb`, depends on `carton` plus `bigdecimal 2.0.3`, and exports both its own version and the `bigdecimal` version it activated. This standalone example imports that file directly; the bundler example imports the same gem by name through `gem 'gem_in_carton', path: '../gem_in_carton'`.

`main.rb` ends with `Process.exit!(0)` as a temporary workaround for the current Ruby 4.0.2 `Ruby::Box` teardown crash.

## Run

```sh
RUBY_BOX=1 bundle exec rake example:gem
```
