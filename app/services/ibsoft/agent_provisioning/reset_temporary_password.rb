class Ibsoft::AgentProvisioning::ResetTemporaryPassword
  class Error < StandardError; end

  Result = Struct.new(:user, :temporary_password, keyword_init: true)

  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    validate!

    temporary_password = Ibsoft::AgentProvisioning::TemporaryPasswordGenerator.generate
    user.update!(password: temporary_password, password_confirmation: temporary_password)

    Result.new(user: user, temporary_password: temporary_password)
  end

  private

  def validate!
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.saml_enabled') if saml_enabled?
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.external_provider') unless user.provider == 'email'
  end

  def saml_enabled?
    account.respond_to?(:saml_enabled?) && account.saml_enabled?
  end
end
