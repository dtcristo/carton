# frozen_string_literal: true

module Bank
  Money = import_relative 'money'
  def self.deposit(money) = money.is_a?(Money)
end

export Bank
