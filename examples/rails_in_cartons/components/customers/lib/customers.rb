# frozen_string_literal: true

# Rails base classes come from the framework Carton; Rails is not loaded in
# this Box.
Framework = import 'framework'
ApplicationRecord = Framework::ApplicationRecord
ApplicationController = Framework::ApplicationController

# A Rails-style app/ layout, loaded by this Carton's own Zeitwerk loader.
require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('../app/models', __dir__))
loader.push_dir(File.expand_path('../app/controllers', __dir__))
loader.setup

# Load app/ now, as Rails does in production, so a broken file fails at
# boot. Constants left to autoload would still load in this Box.
loader.eager_load

# This domain owns its table.
def create_schema(connection)
  connection.create_table(:customers) { |t| t.string :name, null: false }
end

export :Customer, :CustomersController, :create_schema
