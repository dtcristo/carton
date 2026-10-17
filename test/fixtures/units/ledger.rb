# frozen_string_literal: true

# A Carton: this Entrypoint plus the ledger/ directory beside it.
require_relative 'ledger/entry'

module Ledger
  def self.entry = Entry.new
end

export_default Ledger
