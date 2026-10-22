# frozen_string_literal: true

# A legacy patch that prints every Float as money. In plain Ruby this would
# change Float#to_s for the whole process. Here it changes it only in the crm
# Box, so the host, the webhook plugin, and crm_client keep Ruby's Float#to_s.
class Float
  def to_s = format('%.2f', self)
end
