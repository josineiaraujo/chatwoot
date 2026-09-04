# frozen_string_literal: true

module Ibsoft::ConversationDistribution::TeamAssignmentSourceMarker
  extend ActiveSupport::Concern

  included do
    before_validation :mark_ibsoft_action_service_team_assignment
  end

  private

  def mark_ibsoft_action_service_team_assignment
    return unless Ibsoft::ConversationDistribution::TeamAssignmentContext.source_marking_enabled
    return unless will_save_change_to_team_id? && team_id.present?

    Ibsoft::ConversationDistribution::SourceMarker.new(conversation: self).assign
  end
end
