# rubocop:disable Style/OneClassPerFile
class RemoveLegacyIbsoftDistributionLinkConfig < ActiveRecord::Migration[7.1]
  class DistributionPolicy < ApplicationRecord
    self.table_name = 'ibsoft_conversation_distribution_policies'
  end

  class ChannelPolicy < ApplicationRecord
    self.table_name = 'ibsoft_conversation_distribution_channel_policies'
  end

  class TeamPolicy < ApplicationRecord
    self.table_name = 'ibsoft_conversation_distribution_team_policies'
  end

  def up
    return unless table_exists?(:ibsoft_conversation_distribution_policies)

    migrate_legacy_channel_policies
    migrate_legacy_team_policies
    remove_legacy_columns
  end

  def down
    add_legacy_columns(:ibsoft_conversation_distribution_channel_policies)
    add_legacy_columns(:ibsoft_conversation_distribution_team_policies)
  end

  private

  def migrate_legacy_channel_policies
    return unless legacy_columns?(:ibsoft_conversation_distribution_channel_policies)

    ChannelPolicy.reset_column_information
    ChannelPolicy.where(distribution_policy_id: nil).find_each do |channel_policy|
      next unless channel_policy.enabled || channel_policy.config.present?

      channel_policy.update!(
        distribution_policy_id: migrated_policy_for(
          account_id: channel_policy.account_id,
          name: "Politica migrada do canal #{channel_policy.inbox_id}",
          enabled: channel_policy.enabled,
          config: channel_policy.config
        ).id
      )
    end
  end

  def migrate_legacy_team_policies
    return unless legacy_columns?(:ibsoft_conversation_distribution_team_policies)

    TeamPolicy.reset_column_information
    TeamPolicy.where(distribution_policy_id: nil).find_each do |team_policy|
      next unless team_policy.enabled || team_policy.config.present?

      team_policy.update!(
        distribution_policy_id: migrated_policy_for(
          account_id: team_policy.account_id,
          name: "Politica migrada do time #{team_policy.team_id}",
          enabled: team_policy.enabled,
          config: team_policy.config
        ).id
      )
    end
  end

  def migrated_policy_for(account_id:, name:, enabled:, config:)
    DistributionPolicy.create!(
      account_id: account_id,
      name: unique_policy_name(account_id, name),
      enabled: enabled,
      config: config || {}
    )
  end

  def unique_policy_name(account_id, base_name)
    return base_name unless DistributionPolicy.exists?(account_id: account_id, name: base_name)

    counter = 2
    loop do
      candidate = "#{base_name} #{counter}"
      return candidate unless DistributionPolicy.exists?(account_id: account_id, name: candidate)

      counter += 1
    end
  end

  def remove_legacy_columns
    remove_legacy_column(:ibsoft_conversation_distribution_channel_policies, :enabled)
    remove_legacy_column(:ibsoft_conversation_distribution_channel_policies, :config)
    remove_legacy_column(:ibsoft_conversation_distribution_team_policies, :enabled)
    remove_legacy_column(:ibsoft_conversation_distribution_team_policies, :config)
  end

  def remove_legacy_column(table_name, column_name)
    return unless column_exists?(table_name, column_name)

    remove_column table_name, column_name
  end

  def add_legacy_columns(table_name)
    add_column table_name, :enabled, :boolean, null: false, default: false unless column_exists?(table_name, :enabled)
    add_column table_name, :config, :jsonb, null: false, default: {} unless column_exists?(table_name, :config)
  end

  def legacy_columns?(table_name)
    column_exists?(table_name, :enabled) && column_exists?(table_name, :config)
  end
end
# rubocop:enable Style/OneClassPerFile
