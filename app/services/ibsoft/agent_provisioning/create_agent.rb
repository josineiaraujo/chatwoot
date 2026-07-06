class Ibsoft::AgentProvisioning::CreateAgent
  class Error < StandardError; end

  Result = Struct.new(:user, :temporary_password, keyword_init: true)

  VALID_ROLES = %w[agent administrator].freeze

  attr_reader :account, :inviter, :params

  def initialize(account:, inviter:, params:)
    @account = account
    @inviter = inviter
    @params = params
  end

  def perform
    validate!

    temporary_password = Ibsoft::AgentProvisioning::TemporaryPasswordGenerator.generate
    user = nil

    ActiveRecord::Base.transaction do
      user = build_user(temporary_password)
      user.save!
      create_account_user!(user)
      create_profile_assignment!(user)
    end

    attach_avatar!(user)

    Result.new(user: user, temporary_password: temporary_password)
  end

  private

  def validate!
    validate_identity!
    validate_account_rules!
    validate_profile!
    validate_role!
  end

  def validate_identity!
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.name_required') if name.blank?
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.email_required') if email.blank?
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.invalid_email') unless email.match?(URI::MailTo::EMAIL_REGEXP)
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.email_taken') if User.from_email(email).present?
  end

  def validate_account_rules!
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.saml_enabled') if saml_enabled?
    raise Error, I18n.t('ibsoft.agent_provisioning.errors.limit_reached') unless available_agent_count.positive?
  end

  def validate_profile!
    return if profile_id.blank?
    return if profile.present?

    raise Error, I18n.t('ibsoft.agent_provisioning.errors.invalid_profile')
  end

  def validate_role!
    return if profile_id.present?

    raise Error, I18n.t('ibsoft.agent_provisioning.errors.invalid_role') unless VALID_ROLES.include?(role)
  end

  def build_user(temporary_password)
    User.new(
      email: email,
      name: name,
      password: temporary_password,
      password_confirmation: temporary_password
    ).tap(&:skip_confirmation!)
  end

  def create_account_user!(user)
    AccountUser.create!(
      account_id: account.id,
      user_id: user.id,
      inviter_id: inviter.id,
      role: native_role,
      availability: :offline,
      auto_offline: auto_offline
    )
  end

  def create_profile_assignment!(user)
    return if profile.blank?

    Ibsoft::AccessControl::RoleAssignment.create!(
      account: account,
      user: user,
      role: profile,
      created_by: inviter
    )
  end

  def attach_avatar!(user)
    return if avatar.blank?

    Ibsoft::AgentProvisioning::AvatarAttacher.new(user: user, avatar: avatar).perform
  end

  def available_agent_count
    account.usage_limits[:agents] - account.users.count
  end

  def saml_enabled?
    account.respond_to?(:saml_enabled?) && account.saml_enabled?
  end

  def name
    @name ||= params[:name].to_s.strip
  end

  def email
    @email ||= params[:email].to_s.downcase.strip
  end

  def role
    @role ||= params[:role].presence || 'agent'
  end

  def native_role
    profile.present? ? 'agent' : role
  end

  def auto_offline
    return true unless params.key?(:auto_offline) || params.key?('auto_offline')

    value = params.key?(:auto_offline) ? params[:auto_offline] : params['auto_offline']
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def profile_id
    @profile_id ||= params[:profile_id].presence
  end

  def avatar
    params[:avatar]
  end

  def profile
    return if profile_id.blank?

    @profile ||= Ibsoft::AccessControl::Role.find_by(account: account, id: profile_id)
  end
end
