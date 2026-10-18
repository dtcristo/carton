# carton-tools

The `carton` command for [Carton](../README.md). It reads code with Prism and
never runs it, so it needs no `RUBY_BOX=1`.

- `carton check main.rb` reports import and export problems: missing imports,
  cycles, `require` calls that reach into a Carton, missing Named Exports,
  and gems a gem Carton uses without declaring them.
- `carton rbs main.rb` writes `sig/generated/carton.rbs`, so
  [Steep](https://github.com/soutaro/steep) knows what each import returns.

Add it next to `carton`, in the group your checks run in:

```ruby
# Gemfile
gem 'carton'
gem 'carton-tools', group: :development
```

```sh
bundle exec carton check main.rb
```

carton-tools is released with carton and depends on exactly the same
version. See [Types and checks](../docs/usage.md#types-and-checks) for what
each command does.

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
