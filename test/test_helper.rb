# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'package'

module Warning
  class << self
    alias_method :package_original_warn, :warn

    def warn(message, *args, **kwargs)
      if message.include?(
           "minitest/mock.rb:34: warning: redefining 'object_id' may cause serious problems",
         )
        return
      end

      package_original_warn(message, *args, **kwargs)
    end
  end
end

require 'minitest/autorun'
