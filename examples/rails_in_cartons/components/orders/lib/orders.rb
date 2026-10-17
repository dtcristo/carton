# frozen_string_literal: true

Framework = import 'framework'
ApplicationRecord = Framework::ApplicationRecord
ApplicationController = Framework::ApplicationController

# Orders depends on the customers domain and shares its Customer class.
Customer = import('customers')::Customer

require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('../app/models', __dir__))
loader.push_dir(File.expand_path('../app/controllers', __dir__))
loader.setup
loader.eager_load # load app/ in this Box; see customers.rb

def create_schema(connection)
  connection.create_table(:orders) do |t|
    t.references :customer, null: false
    t.integer :total_cents, null: false
  end
end

export :Order, :OrdersController, :create_schema
