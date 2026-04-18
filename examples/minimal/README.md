# Minimal example

Smallest working example of the library.

`main.rb` ends with `Process.exit!(0)` as a temporary workaround for the current Ruby 4.0.2 `Ruby::Box` teardown crash.

## What it shows

- single export (`foo.rb`, `baz.rb`)
- named exports (`bar.rb`)
- `import_relative`
- one carton importing another carton internally

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```
