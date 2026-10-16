# frozen_string_literal: true

Money = import_relative('money')::Money

def pay(cents) = Money.new(cents)

export :pay, Money:
