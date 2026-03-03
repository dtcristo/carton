$LOAD_PATH.unshift('../../lib')
require 'rb/package'

Faker = import('faker')::Faker

puts "Hello, #{Faker::Name.name}!"
