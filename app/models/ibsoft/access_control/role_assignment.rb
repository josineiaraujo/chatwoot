# == Schema Information
#
# Table name: ibsoft_access_control_role_assignments
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint
#  role_id       :bigint           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  idx_ibsoft_access_assignments_account_user                     (account_id,user_id) UNIQUE
#  idx_ibsoft_access_assignments_role_id                          (role_id)
#  index_ibsoft_access_control_role_assignments_on_account_id     (account_id)
#  index_ibsoft_access_control_role_assignments_on_created_by_id  (created_by_id)
#  index_ibsoft_access_control_role_assignments_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (role_id => ibsoft_access_control_roles.id)
#  fk_rails_...  (user_id => users.id)
#
class Ibsoft::AccessControl::RoleAssignment < ApplicationRecord
  self.table_name = 'ibsoft_access_control_role_assignments'

  belongs_to :account
  belongs_to :role, class_name: 'Ibsoft::AccessControl::Role'
  belongs_to :user
  belongs_to :created_by, class_name: '::User', optional: true

  validates :user_id, uniqueness: { scope: :account_id }
  validate :role_belongs_to_account
  validate :user_belongs_to_account
  validate :creator_belongs_to_account

  def payload
    {
      id: id,
      account_id: account_id,
      role: role.payload,
      user: user_payload(user),
      created_by: user_payload(created_by),
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def role_belongs_to_account
    return if role.blank? || account_id.blank?
    return if role.account_id == account_id

    errors.add(:role, 'must belong to account')
  end

  def user_belongs_to_account
    return if user.blank? || account_id.blank?
    return if AccountUser.exists?(account_id: account_id, user_id: user_id)

    errors.add(:user, 'must belong to account')
  end

  def creator_belongs_to_account
    return if created_by.blank? || account_id.blank?
    return if AccountUser.exists?(account_id: account_id, user_id: created_by_id)

    errors.add(:created_by, 'must belong to account')
  end

  def user_payload(payload_user)
    return if payload_user.blank?

    {
      id: payload_user.id,
      name: payload_user.name,
      email: payload_user.email,
      avatar_url: payload_user.avatar_url
    }
  end
end
