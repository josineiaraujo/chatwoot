# == Schema Information
#
# Table name: ibsoft_access_control_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string           not null
#  permissions :text             default([]), not null, is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  idx_ibsoft_access_control_roles_account_name     (account_id,name) UNIQUE
#  index_ibsoft_access_control_roles_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Ibsoft::AccessControl::Role < ApplicationRecord
  self.table_name = 'ibsoft_access_control_roles'

  belongs_to :account
  has_many :role_assignments,
           class_name: 'Ibsoft::AccessControl::RoleAssignment',
           dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validate :permissions_are_known

  def payload
    {
      id: id,
      account_id: account_id,
      name: name,
      description: description,
      permissions: permissions,
      assignments_count: role_assignments.size,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def permissions_are_known
    unknown_permissions = permissions - Ibsoft::AccessControl::PermissionCatalog.keys
    return if unknown_permissions.blank?

    errors.add(:permissions, :inclusion, value: unknown_permissions.join(', '))
  end
end
