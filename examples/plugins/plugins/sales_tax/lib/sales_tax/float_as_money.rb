# frozen_string_literal: true

# A legacy patch that prints every Float as money. In plain Ruby this would
# change Float#to_s for the whole process. Here it changes it only in the
# sales_tax Box, so the host and the growth plugin keep Ruby's Float#to_s.
class Float
  def to_s = format('%.2f', self)
end
