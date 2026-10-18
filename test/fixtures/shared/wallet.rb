# frozen_string_literal: true

Money = import_relative('money')

def pay(cents) = Money.new(cents)
