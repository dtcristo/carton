# Gems example

Flat, non-Bundler example showing two cartons manually activating different `bigdecimal` versions with RubyGems.

`main.rb`, `bigdecimal4.rb`, and `bigdecimal3.rb` all live at the same level. Each carton calls `Carton.bootstrap_rubygems!`, activates one `bigdecimal` version with `gem`, then requires it and exports `BigDecimal::VERSION`.

## Run

```sh
gem install bigdecimal -v 4.1.1
gem install bigdecimal -v 3.3.1
RUBY_BOX=1 ruby examples/gems/main.rb
```

Or let the repo task install any missing versions into your normal gem home:

```sh
RUBY_BOX=1 bundle exec rake example:gems
```
