# frozen_string_literal: true

module Wallet
  Money = import_relative 'money'
  def self.pay(cents) = Money.new(cents)
end

export Wallet
