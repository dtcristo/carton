# Minimal example

Smallest working example of the library with no gems or Bundler involved.

## What it shows

- constant export of a module (`foo.rb`, `baz.rb`)
- named exports (`bar.rb`)
- `import_relative`
- one carton importing another carton internally

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```
