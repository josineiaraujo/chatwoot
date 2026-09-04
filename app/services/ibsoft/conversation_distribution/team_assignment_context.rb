# frozen_string_literal: true

class Ibsoft::ConversationDistribution::TeamAssignmentContext < ActiveSupport::CurrentAttributes
  attribute :source_marking_enabled

  def self.with_source_marking(&)
    set({ source_marking_enabled: true }, &)
  end
end
