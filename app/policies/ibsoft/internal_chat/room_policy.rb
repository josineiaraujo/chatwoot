class Ibsoft::InternalChat::RoomPolicy < ApplicationPolicy
  def index?
    account_member?
  end

  def show?
    room_member?
  end

  def create?
    account_member?
  end

  def update?
    room_member? && record.room?
  end

  def destroy?
    return false unless account_room?
    return true if account_admin?

    record.room? && room_creator?
  end

  def manage_members?
    room_member? && record.room? && room_creator?
  end

  def post_message?
    room_member?
  end

  private

  def account_member?
    account_user.present?
  end

  def room_member?
    return false unless account_member?
    return false unless account_room?

    record.memberships.exists?(user_id: user.id)
  end

  def account_room?
    record.account_id == account.id
  end

  def room_creator?
    record.created_by_id == user.id
  end

  def account_admin?
    account_user&.administrator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if account_user.blank?

      scope
        .where(account_id: account.id)
        .joins(:memberships)
        .where(ibsoft_internal_chat_memberships: { user_id: user.id })
        .distinct
    end
  end
end
