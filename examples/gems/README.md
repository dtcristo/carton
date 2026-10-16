# Gems example

Two Cartons using different `bigdecimal` versions in one process, with plain
RubyGems and no Bundler.

`bigdecimal3.rb` and `bigdecimal4.rb` each activate one version with `gem`,
require it, and export `BigDecimal::VERSION`. `main.rb` imports both.

## Run

```sh
gem install bigdecimal -v 3.3.1
gem install bigdecimal -v 4.1.1
RUBY_BOX=1 ruby examples/gems/main.rb
```

Or run it with `bundle exec rake example:gems`, which installs both versions.
