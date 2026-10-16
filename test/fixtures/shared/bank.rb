# frozen_string_literal: true

Money = import_relative('money')::Money

def deposit(money) = money.is_a?(Money)

export :deposit, Money:
