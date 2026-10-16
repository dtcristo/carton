Sibling = import_relative('single_export')::User

def greeting = Sibling.new('World').greet

export :greeting
