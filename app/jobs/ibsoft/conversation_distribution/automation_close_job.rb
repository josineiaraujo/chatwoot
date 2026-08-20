class Ibsoft::ConversationDistribution::AutomationCloseJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(schedule_id)
    schedule = Ibsoft::ConversationDistribution::AutomationCloseSchedule.find_by(id: schedule_id)
    return { status: 'schedule_not_found' } if schedule.blank?

    Ibsoft::ConversationDistribution::AutomationCloseExecutor.new(
      account: schedule.account,
      schedule_id: schedule.id
    ).perform
  end
end
