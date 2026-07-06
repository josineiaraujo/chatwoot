class Ibsoft::PermissionRegistry
  PROVIDERS = [
    Ibsoft::AccessControl::PermissionResolver
  ].freeze

  def self.permissions_for(account_user)
    PROVIDERS.flat_map { |provider| provider.permissions_for(account_user) }.uniq
  end
end
