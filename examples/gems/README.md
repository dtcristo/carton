# Gems example

Flat, non-Bundler example showing two cartons manually activating different `bigdecimal` versions with RubyGems.

`main.rb`, `bigdecimal3.rb`, and `bigdecimal4.rb` all live at the same level. Each carton calls `Carton.bootstrap_rubygems!`, activates one `bigdecimal` version with `gem`, then requires it and exports `BigDecimal::VERSION`.

## Run

```sh
gem install bigdecimal -v 3.3.1
gem install bigdecimal -v 4.1.1
RUBY_BOX=1 ruby examples/gems/main.rb
```

Run through the Rake task or directly with `RUBY_BOX=1`. The remaining upstream
`bundle exec` gemspec failure does not block this example.
