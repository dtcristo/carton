# Minimal example

Smallest working example of the library with no gems or Bundler involved.

`main.rb` uses an `at_exit` hard exit as a temporary Ruby 4.0.2 workaround after boxed loads.

## What it shows

- single export (`foo.rb`, `baz.rb`)
- named exports (`bar.rb`)
- `import_relative`
- one carton importing another carton internally

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```
