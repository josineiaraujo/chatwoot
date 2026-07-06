class AddIbsoftDistributionEventLogPerformanceIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :ibsoft_conversation_distribution_event_logs,
              [:account_id, :conversation_id, :event_type, :reason, :created_at, :id],
              order: { created_at: :desc, id: :desc },
              algorithm: :concurrently,
              name: 'idx_ibsoft_dist_events_dedupe',
              if_not_exists: true

    add_index :ibsoft_conversation_distribution_event_logs,
              [:account_id, :event_type, :conversation_id, :created_at, :id],
              order: { created_at: :desc, id: :desc },
              algorithm: :concurrently,
              name: 'idx_ibsoft_dist_events_latest_assignment',
              if_not_exists: true

    add_index :ibsoft_conversation_distribution_event_logs,
              [:account_id, :event_type, :reason, :created_at, :id],
              order: { created_at: :desc, id: :desc },
              algorithm: :concurrently,
              name: 'idx_ibsoft_dist_events_filters',
              if_not_exists: true
  end
end
