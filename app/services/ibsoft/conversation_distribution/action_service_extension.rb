module Ibsoft::ConversationDistribution::ActionServiceExtension
  def assign_team(team_ids = [])
    Ibsoft::ConversationDistribution::TeamAssignmentContext.with_source_marking do
      super(team_ids)
    end
  end
end
