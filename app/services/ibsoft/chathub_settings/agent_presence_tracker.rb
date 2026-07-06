class Ibsoft::ChathubSettings::AgentPresenceTracker
  def self.sync_account!(account)
    new(account).sync_account!
  end

  def initialize(account)
    @account = account
    @now = Time.current
  end

  def sync_account!
    account.account_users.find_each do |account_user|
      sync_account_user(account_user)
    end
  end

  private

  attr_reader :account, :now

  def sync_account_user(account_user)
    state = Ibsoft::ChathubSettings::AgentPresenceState.find_or_initialize_by(
      account: account,
      user_id: account_user.user_id
    )
    status = current_status_for(account_user)

    if state.new_record?
      assign_initial_state(state, status)
    elsif state.current_status != status
      assign_changed_state(state, status)
    end

    state.save! if state.changed?
  end

  def assign_initial_state(state, status)
    state.current_status = status
    state.last_status_changed_at = now
    assign_status_timestamp(state, status)
  end

  def assign_changed_state(state, status)
    state.current_status = status
    state.last_status_changed_at = now
    assign_status_timestamp(state, status)
  end

  def assign_status_timestamp(state, status)
    if status == 'online'
      state.last_online_at = now
    else
      state.last_offline_at = now
    end
  end

  def current_status_for(account_user)
    available_user_statuses.fetch(account_user.user_id.to_s, 'offline')
  end

  def available_user_statuses
    @available_user_statuses ||= OnlineStatusTracker.get_available_users(account.id).transform_keys(&:to_s)
  end
end
