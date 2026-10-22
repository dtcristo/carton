# frozen_string_literal: true

Hanami.app.configure_provider :db do
  config.gateway :default do |gateway|
    # Keep Hanami's DATABASE_URL and derived test-database conventions.
    if Hanami.env?(:test)
      gateway.database_url =
        Hanami::DB::Testing.database_url(
          ENV.fetch('DATABASE_URL', 'sqlite://db/shop.sqlite3'),
        )
    end

    gateway.database_url ||=
      ENV.fetch('DATABASE_URL', 'sqlite://db/shop.sqlite3')
  end
end
