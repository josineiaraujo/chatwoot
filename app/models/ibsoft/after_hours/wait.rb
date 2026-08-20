# == Schema Information
#
# Table name: ibsoft_after_hours_waits
#
#  id                        :bigint           not null, primary key
#  cause                     :string           not null
#  exit_command              :string           not null
#  exit_confirmation_message :text             not null
#  finished_at               :datetime
#  started_at                :datetime         not null
#  status                    :string           default("active"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  after_hours_policy_id     :bigint           not null
#  business_calendar_id      :bigint
#  business_holiday_id       :bigint
#  conversation_id           :bigint           not null
#  entry_message_id          :bigint
#  exit_message_id           :bigint
#  team_id                   :bigint
#
# Indexes
#
#  idx_ibsoft_after_hours_waits_account_status        (account_id,status)
#  idx_ibsoft_after_hours_waits_calendar              (business_calendar_id)
#  idx_ibsoft_after_hours_waits_entry_message         (entry_message_id)
#  idx_ibsoft_after_hours_waits_exit_message          (exit_message_id)
#  idx_ibsoft_after_hours_waits_holiday               (business_holiday_id)
#  idx_ibsoft_after_hours_waits_policy                (after_hours_policy_id)
#  index_ibsoft_after_hours_waits_on_account_id       (account_id)
#  index_ibsoft_after_hours_waits_on_conversation_id  (conversation_id) UNIQUE
#  index_ibsoft_after_hours_waits_on_team_id          (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (after_hours_policy_id => ibsoft_after_hours_policies.id) ON DELETE => cascade
#  fk_rails_...  (business_calendar_id => ibsoft_business_calendars.id) ON DELETE => nullify
#  fk_rails_...  (business_holiday_id => ibsoft_business_holidays.id) ON DELETE => nullify
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (entry_message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (exit_message_id => messages.id) ON DELETE => nullify
#  fk_rails_...  (team_id => teams.id) ON DELETE => nullify
#
class Ibsoft::AfterHours::Wait < ApplicationRecord
  self.table_name = 'ibsoft_after_hours_waits'

  STATUSES = %w[active cancelled exited].freeze
  CAUSES = %w[schedule holiday].freeze
  ACCOUNT_SCOPED_ASSOCIATIONS = %i[
    conversation after_hours_policy team business_calendar business_holiday entry_message exit_message
  ].freeze

  belongs_to :account
  belongs_to :conversation, class_name: '::Conversation'
  belongs_to :after_hours_policy,
             class_name: 'Ibsoft::AfterHours::Policy',
             inverse_of: :waits
  belongs_to :team, optional: true
  belongs_to :business_calendar, class_name: 'Ibsoft::BusinessCalendar::Calendar', optional: true
  belongs_to :business_holiday, class_name: 'Ibsoft::BusinessCalendar::Holiday', optional: true
  belongs_to :entry_message, class_name: 'Message', optional: true
  belongs_to :exit_message, class_name: 'Message', optional: true

  before_validation :snapshot_policy_messages

  validates :conversation_id, uniqueness: true
  validates :exit_command, :exit_confirmation_message, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :cause, inclusion: { in: CAUSES }
  validate :records_belong_to_account

  scope :active, -> { where(status: 'active') }

  def active?
    status == 'active'
  end

  private

  def snapshot_policy_messages
    self.exit_command = after_hours_policy&.exit_command if exit_command.blank?
    self.exit_confirmation_message = after_hours_policy&.exit_confirmation_message if exit_confirmation_message.blank?
  end

  def records_belong_to_account
    ACCOUNT_SCOPED_ASSOCIATIONS.each do |association_name|
      record = public_send(association_name)
      errors.add(association_name, :invalid) if record.present? && record.account_id != account_id
    end
  end
end
