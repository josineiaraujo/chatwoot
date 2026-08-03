# == Schema Information
#
# Table name: ibsoft_message_broadcasts
#
#  id                 :bigint           not null, primary key
#  conversation_mode  :string           default("direct"), not null
#  dispatch_mode      :string           default("bulk"), not null
#  finished_at        :datetime
#  source_type        :string           not null
#  started_at         :datetime
#  status             :string           default("draft"), not null
#  template_language  :string           not null
#  template_name      :string           not null
#  template_variables :jsonb            not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  assignee_id        :bigint
#  created_by_id      :bigint           not null
#  erp_connection_id  :bigint           not null
#  inbox_id           :bigint           not null
#  sent_by_id         :bigint
#  team_id            :bigint
#
# Indexes
#
#  idx_ibsoft_broadcasts_account_created                 (account_id,created_at)
#  idx_ibsoft_broadcasts_dispatch                        (status,updated_at)
#  index_ibsoft_message_broadcasts_on_account_id         (account_id)
#  index_ibsoft_message_broadcasts_on_assignee_id        (assignee_id)
#  index_ibsoft_message_broadcasts_on_created_by_id      (created_by_id)
#  index_ibsoft_message_broadcasts_on_erp_connection_id  (erp_connection_id)
#  index_ibsoft_message_broadcasts_on_inbox_id           (inbox_id)
#  index_ibsoft_message_broadcasts_on_sent_by_id         (sent_by_id)
#  index_ibsoft_message_broadcasts_on_team_id            (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (erp_connection_id => ibsoft_erp_connections.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
class Ibsoft::MessageBroadcast::Broadcast < ApplicationRecord
  self.table_name = 'ibsoft_message_broadcasts'

  STATUSES = %w[draft queued running completed failed cancelled].freeze
  DELETABLE_STATUSES = %w[draft completed failed cancelled].freeze
  SOURCE_TYPES = %w[selection group].freeze
  DISPATCH_MODES = %w[single bulk].freeze
  CONVERSATION_MODES = %w[direct close_after_send keep_open].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :erp_connection, class_name: 'Ibsoft::Erp::Connection'
  belongs_to :created_by, class_name: 'User'
  belongs_to :sent_by, class_name: 'User', optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true
  has_many :recipients,
           class_name: 'Ibsoft::MessageBroadcast::Recipient',
           inverse_of: :broadcast,
           dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :dispatch_mode, inclusion: { in: DISPATCH_MODES }
  validates :conversation_mode, inclusion: { in: CONVERSATION_MODES }
  validates :template_name, :template_language, presence: true

  def single_dispatch? = dispatch_mode == 'single'
  def direct_delivery? = conversation_mode == 'direct'
  def deletable? = status.in?(DELETABLE_STATUSES)

  def payload(recipients_count: nil)
    {
      id: id,
      inbox_id: inbox_id,
      erp_connection_id: erp_connection_id,
      status: status,
      deletable: deletable?,
      source_type: source_type,
      dispatch_mode: dispatch_mode,
      template_name: template_name,
      template_language: template_language,
      conversation_mode: conversation_mode,
      sent_by_id: sent_by_id,
      created_by: { id: created_by_id, name: created_by.name },
      recipients_count: recipients_count.nil? ? recipients.count : recipients_count,
      started_at: started_at,
      finished_at: finished_at,
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
