# == Schema Information
#
# Table name: ibsoft_chathub_agent_presence_states
#
#  id                     :bigint           not null, primary key
#  current_status         :string           default("offline"), not null
#  last_offline_at        :datetime
#  last_online_at         :datetime
#  last_status_changed_at :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  user_id                :bigint           not null
#
# Indexes
#
#  idx_ibsoft_chathub_agent_presence_state                   (account_id,user_id) UNIQUE
#  index_ibsoft_chathub_agent_presence_states_on_account_id  (account_id)
#  index_ibsoft_chathub_agent_presence_states_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Ibsoft::ChathubSettings::AgentPresenceState < ApplicationRecord
  self.table_name = 'ibsoft_chathub_agent_presence_states'

  belongs_to :account
  belongs_to :user

  validates :user_id, uniqueness: { scope: :account_id }
  validates :current_status, presence: true
end
