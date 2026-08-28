# == Schema Information
#
# Table name: ibsoft_after_hours_policies
#
#  id                        :bigint           not null, primary key
#  enabled                   :boolean          default(FALSE), not null
#  exit_command              :string           default("sair"), not null
#  exit_confirmation_message :text
#  holiday_message           :text
#  name                      :string           not null
#  regular_message           :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#
# Indexes
#
#  idx_ibsoft_after_hours_policies_account_name     (account_id,name) UNIQUE
#  index_ibsoft_after_hours_policies_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class Ibsoft::AfterHours::Policy < ApplicationRecord
  self.table_name = 'ibsoft_after_hours_policies'

  belongs_to :account
  has_many :distribution_policies,
           class_name: 'Ibsoft::ConversationDistribution::Policy',
           foreign_key: :after_hours_policy_id,
           inverse_of: :after_hours_policy,
           dependent: :nullify
  has_many :waits,
           class_name: 'Ibsoft::AfterHours::Wait',
           foreign_key: :after_hours_policy_id,
           inverse_of: :after_hours_policy,
           dependent: :destroy

  before_validation :normalize_exit_command
  before_destroy :prevent_destroy_with_active_waits, prepend: true

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :exit_command, presence: true, length: { maximum: 50 }, format: { without: /[\r\n]/ }
  validate :required_messages_when_enabled

  def payload
    {
      id: id,
      account_id: account_id,
      name: name,
      enabled: enabled?,
      exit_command: exit_command,
      regular_message: regular_message,
      holiday_message: holiday_message,
      exit_confirmation_message: exit_confirmation_message,
      linked_distribution_policies_count: distribution_policies.size,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def normalize_exit_command
    self.exit_command = exit_command.to_s.gsub(/[[:blank:]]+/, ' ').strip.downcase
  end

  def required_messages_when_enabled
    return unless enabled?

    %i[regular_message holiday_message exit_confirmation_message].each do |attribute|
      errors.add(attribute, :blank) if public_send(attribute).blank?
    end
  end

  def prevent_destroy_with_active_waits
    return unless waits.active.exists?

    errors.add(:base, :restrict_dependent_destroy, record: 'active waits')
    throw(:abort)
  end
end
