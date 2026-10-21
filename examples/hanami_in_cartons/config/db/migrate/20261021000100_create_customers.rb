# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :customers do
      primary_key :id
      String :name, null: false
    end
  end
end
