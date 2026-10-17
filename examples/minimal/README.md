# Minimal example

The smallest working example, with no gems or Bundler.

## What it shows

- a Default Export with `export_default` (`foo.rb`, `baz.rb`)
- Named Exports with `export` (`bar.rb`)
- `import_relative`
- one Carton importing another (`bar.rb` imports `baz.rb`)

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```
