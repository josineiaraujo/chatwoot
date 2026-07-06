require 'securerandom'

class Ibsoft::ConversationDistribution::WatchdogRunner
  DEFAULT_ACCOUNT_BATCH_SIZE = 100
  LOCK_KEY = 'IBSOFT_CONVERSATION_DISTRIBUTION::WATCHDOG::%<scope>s'.freeze
  SUMMARY_COUNTER_KEYS = %i[scanned assigned redistributed skipped ignored].freeze

  def initialize(account_id: nil, inbox_id: nil, team_id: nil, limit: Ibsoft::ConversationDistribution::ExecutionConfig.job_limit)
    @account_id = account_id
    @inbox_id = inbox_id
    @team_id = team_id
    @limit = limit
  end

  def perform
    return disabled_payload unless Ibsoft::ConversationDistribution::ExecutionConfig.job_enabled?
    return locked_payload unless acquire_lock

    account_results = []
    account_scope.find_each(batch_size: account_batch_size) do |account|
      account_results << run_account(account)
    end

    result_payload(account_results)
  ensure
    release_lock if @lock_token.present?
  end

  private

  attr_reader :account_id, :inbox_id, :team_id, :limit

  def disabled_payload
    {
      enabled: false,
      locked: false,
      generated_at: Time.current.iso8601,
      summary: empty_summary,
      accounts: []
    }
  end

  def locked_payload
    {
      enabled: true,
      locked: true,
      generated_at: Time.current.iso8601,
      limit: safe_limit,
      summary: empty_summary,
      accounts: []
    }
  end

  def result_payload(account_results)
    {
      enabled: true,
      locked: false,
      generated_at: Time.current.iso8601,
      limit: safe_limit,
      summary: summary_payload(account_results),
      accounts: account_results
    }
  end

  def run_account(account)
    sync_presence_if_needed(account)

    assignment_result = assignment_executor(account).perform
    redistribution_result = redistribution_executor(account).perform

    account_result_payload(account, assignment_result, redistribution_result)
  end

  def assignment_executor(account)
    Ibsoft::ConversationDistribution::AssignmentExecutor.new(
      account: account,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: safe_limit
    )
  end

  def redistribution_executor(account)
    Ibsoft::ConversationDistribution::RedistributionExecutor.new(
      account: account,
      inbox_id: inbox_id,
      team_id: team_id,
      limit: safe_limit
    )
  end

  def account_result_payload(account, assignment_result, redistribution_result)
    {
      account_id: account.id,
      real_assignment_enabled: assignment_result[:real_assignment_enabled],
      filters: assignment_result[:filters],
      assignment_summary: assignment_result[:summary],
      redistribution_summary: redistribution_result[:summary],
      summary: combined_account_summary(assignment_result[:summary], redistribution_result[:summary])
    }
  end

  def summary_payload(account_results)
    account_results.each_with_object(empty_summary.merge(accounts: account_results.size)) do |result, summary|
      merge_summary!(summary, result[:summary])
    end
  end

  def combined_account_summary(assignment_summary, redistribution_summary)
    [assignment_summary, redistribution_summary].each_with_object(empty_summary.except(:accounts)) do |partial_summary, summary|
      merge_summary!(summary, partial_summary)
    end
  end

  def merge_summary!(summary, partial_summary)
    SUMMARY_COUNTER_KEYS.each { |key| summary[key] += partial_summary[key].to_i }
    partial_summary[:by_reason].to_h.each do |reason, count|
      summary[:by_reason][reason] = summary[:by_reason].fetch(reason, 0) + count.to_i
    end
  end

  def empty_summary
    {
      accounts: 0,
      scanned: 0,
      assigned: 0,
      redistributed: 0,
      skipped: 0,
      ignored: 0,
      by_reason: {}
    }
  end

  def account_scope
    return Account.where(id: account_id) if account_id.present?

    policy_account_scope
  end

  def policy_account_scope
    Account.where(id: active_channel_account_ids)
           .or(Account.where(id: active_team_account_ids))
           .distinct
  end

  def active_channel_account_ids
    distribution_link_scope(Ibsoft::ConversationDistribution::ChannelPolicy)
      .select(:account_id)
  end

  def active_team_account_ids
    distribution_link_scope(Ibsoft::ConversationDistribution::TeamPolicy)
      .where(override_channel_policy: true)
      .select(:account_id)
  end

  def distribution_link_scope(model)
    model.joins(:distribution_policy)
         .where(ibsoft_conversation_distribution_policies: { enabled: true })
  end

  def safe_limit
    @safe_limit ||= begin
      requested_limit = limit.to_i
      requested_limit = Ibsoft::ConversationDistribution::CandidateFinder::DEFAULT_LIMIT unless requested_limit.positive?

      [requested_limit, Ibsoft::ConversationDistribution::CandidateFinder::MAX_LIMIT].min
    end
  end

  def account_batch_size
    DEFAULT_ACCOUNT_BATCH_SIZE
  end

  def sync_presence_if_needed(account)
    return unless login_stabilization_enabled?(account)

    Ibsoft::ChathubSettings::AgentPresenceTracker.sync_account!(account)
  end

  def login_stabilization_enabled?(account)
    ActiveModel::Type::Boolean.new.cast(
      Ibsoft::ChathubSettings::SettingsResolver
        .config_for(account)
        .dig('login_stabilization', 'enabled')
    )
  end

  def acquire_lock
    @lock_token = SecureRandom.uuid
    Redis::Alfred.set(lock_key, @lock_token, nx: true, ex: Ibsoft::ConversationDistribution::ExecutionConfig.watchdog_lock_ttl).present?
  end

  def release_lock
    Redis::Alfred.delete_if_equals(lock_key, @lock_token)
  ensure
    @lock_token = nil
  end

  def lock_key
    format(LOCK_KEY, scope: [account_id || 'all', inbox_id || 'all', team_id || 'all'].join(':'))
  end
end
