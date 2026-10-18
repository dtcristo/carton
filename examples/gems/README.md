# Gems example

A Ruby process normally loads one version of each gem, so two parts of an app that need different versions of the same gem cannot run together. Each Carton has its own Box and its own loaded gems. Here two Cartons load different `bigdecimal` versions in one process, with plain RubyGems and no Bundler.

`bigdecimal3.rb` and `bigdecimal4.rb` each activate one version with `gem`, require it, and export a Hash containing `BigDecimal::VERSION`. `main.rb` imports both. For the Bundler equivalent, see [bundler](../bundler/README.md); for a plugin host that uses the conflicting APIs, see [plugins](../plugins/README.md).

## Run

```sh
gem install bigdecimal -v 3.3.1
gem install bigdecimal -v 4.1.1
RUBY_BOX=1 ruby examples/gems/main.rb
```

Or run it with `bundle exec rake example:gems`, which installs both versions.
