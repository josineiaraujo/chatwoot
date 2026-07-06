# == Schema Information
#
# Table name: ibsoft_conversation_distribution_event_logs
#
#  id                   :bigint           not null, primary key
#  event_type           :string           not null
#  metadata             :jsonb            not null
#  reason               :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  conversation_id      :bigint
#  inbox_id             :bigint
#  new_assignee_id      :bigint
#  previous_assignee_id :bigint
#  team_id              :bigint
#
# Indexes
#
#  idx_ibsoft_dist_events_dedupe                                  (account_id,conversation_id,event_type,reason,created_at DESC,id DESC)
#  idx_ibsoft_dist_events_filters                                 (account_id,event_type,reason,created_at DESC,id DESC)
#  idx_ibsoft_dist_events_latest_assignment                       (account_id,event_type,conversation_id,created_at DESC,id DESC)
#  idx_ibsoft_distribution_events_account_created                 (account_id,created_at)
#  idx_ibsoft_distribution_events_conversation_created            (conversation_id,created_at)
#  idx_on_account_id_f411ea7c53                                   (account_id)
#  idx_on_conversation_id_fd153e5c47                              (conversation_id)
#  idx_on_new_assignee_id_538e25b841                              (new_assignee_id)
#  idx_on_previous_assignee_id_031e5475e3                         (previous_assignee_id)
#  index_ibsoft_conversation_distribution_event_logs_on_inbox_id  (inbox_id)
#  index_ibsoft_conversation_distribution_event_logs_on_team_id   (team_id)
#
class Ibsoft::ConversationDistribution::EventLog < ApplicationRecord
  self.table_name = 'ibsoft_conversation_distribution_event_logs'

  belongs_to :account, class_name: '::Account'
  belongs_to :conversation, class_name: '::Conversation', optional: true
  belongs_to :inbox, class_name: '::Inbox', optional: true
  belongs_to :team, class_name: '::Team', optional: true
  belongs_to :previous_assignee, class_name: '::User', optional: true
  belongs_to :new_assignee, class_name: '::User', optional: true

  validates :event_type, presence: true
end
