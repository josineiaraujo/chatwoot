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
