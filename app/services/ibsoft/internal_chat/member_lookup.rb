class Ibsoft::InternalChat::MemberLookup
  def initialize(account:)
    @account = account
  end

  def users_for(user_ids)
    ids = Array(user_ids).map(&:to_i).reject(&:zero?).uniq
    users = @account.users.where(id: ids).to_a
    return users if users.size == ids.size

    raise Ibsoft::InternalChat::Error, I18n.t('ibsoft_internal_chat.errors.invalid_members')
  end
end
