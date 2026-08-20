# frozen_string_literal: true

class ConfigureIbsoftInboxDeletionForeignKeys < ActiveRecord::Migration[7.1]
  CASCADE_INBOX_TABLES = %i[
    ibsoft_conversation_distribution_automation_handoff_policies
    ibsoft_external_message_deliveries
    ibsoft_external_message_endpoints
    ibsoft_external_message_order_updates
    ibsoft_external_message_orders
    ibsoft_message_broadcasts
    ibsoft_working_hour_breaks
  ].freeze

  def up
    configure_inbox_foreign_keys(on_delete: :cascade)
    configure_broadcast_recipient_foreign_keys(broadcast_on_delete: :cascade, reference_on_delete: :nullify)
    cleanup_orphaned_inbox_references
    add_private_inbox_foreign_keys
  end

  def down
    remove_private_inbox_foreign_keys
    configure_inbox_foreign_keys(on_delete: nil)
    configure_broadcast_recipient_foreign_keys(broadcast_on_delete: nil, reference_on_delete: nil)
  end

  private

  def replace_foreign_key(from_table, to_table, column:, on_delete: nil)
    remove_foreign_key(from_table, column: column) if foreign_key_exists?(from_table, to_table, column: column)
    add_foreign_key(from_table, to_table, column: column, on_delete: on_delete)
  end

  def configure_inbox_foreign_keys(on_delete:)
    CASCADE_INBOX_TABLES.each do |table|
      replace_foreign_key(table, :inboxes, column: :inbox_id, on_delete: on_delete)
    end
  end

  def configure_broadcast_recipient_foreign_keys(broadcast_on_delete:, reference_on_delete:)
    foreign_keys = [
      [:ibsoft_message_broadcasts, :broadcast_id, broadcast_on_delete],
      [:conversations, :conversation_id, reference_on_delete],
      [:messages, :message_id, reference_on_delete]
    ]

    foreign_keys.each do |table, column, on_delete|
      replace_foreign_key(:ibsoft_message_broadcast_recipients, table, column: column, on_delete: on_delete)
    end
  end

  def cleanup_orphaned_inbox_references
    delete_orphaned_channel_policies
    delete_orphaned_team_policies
    nullify_orphaned_event_logs
  end

  def delete_orphaned_channel_policies
    execute <<~SQL.squish
      DELETE FROM ibsoft_conversation_distribution_channel_policies AS policies
      WHERE NOT EXISTS (
        SELECT 1 FROM inboxes WHERE inboxes.id = policies.inbox_id
      )
    SQL
  end

  def delete_orphaned_team_policies
    execute <<~SQL.squish
      DELETE FROM ibsoft_conversation_distribution_team_policies AS policies
      WHERE policies.inbox_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM inboxes WHERE inboxes.id = policies.inbox_id
        )
    SQL
  end

  def nullify_orphaned_event_logs
    execute <<~SQL.squish
      UPDATE ibsoft_conversation_distribution_event_logs AS event_logs
      SET inbox_id = NULL
      WHERE event_logs.inbox_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM inboxes WHERE inboxes.id = event_logs.inbox_id
        )
    SQL
  end

  def add_private_inbox_foreign_keys
    add_foreign_key(
      :ibsoft_conversation_distribution_channel_policies,
      :inboxes,
      column: :inbox_id,
      on_delete: :cascade
    )
    add_foreign_key(
      :ibsoft_conversation_distribution_team_policies,
      :inboxes,
      column: :inbox_id,
      on_delete: :cascade
    )
    add_foreign_key(
      :ibsoft_conversation_distribution_event_logs,
      :inboxes,
      column: :inbox_id,
      on_delete: :nullify
    )
  end

  def remove_private_inbox_foreign_keys
    remove_foreign_key(
      :ibsoft_conversation_distribution_channel_policies,
      column: :inbox_id
    )
    remove_foreign_key(
      :ibsoft_conversation_distribution_team_policies,
      column: :inbox_id
    )
    remove_foreign_key(
      :ibsoft_conversation_distribution_event_logs,
      column: :inbox_id
    )
  end
end
