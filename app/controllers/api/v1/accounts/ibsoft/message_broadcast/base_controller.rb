class Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization!

  private

  def check_admin_authorization!
    return if Current.account_user&.administrator?

    raise Pundit::NotAuthorizedError
  end

  def active_erp_connection
    @active_erp_connection ||= Ibsoft::Erp::Connection.find_by(account: Current.account, active: true)
  end

  def ensure_active_erp_connection!
    return true if active_erp_connection.present?

    render json: { error: 'active_erp_connection_missing' }, status: :unprocessable_entity
    false
  end

  def ensure_ixc_provider!
    return true if active_erp_connection&.provider == 'ixc'

    render json: { error: 'erp_provider_not_supported' }, status: :unprocessable_entity
    false
  end

  def ixc_client
    @ixc_client ||= Ibsoft::Erp::Adapters::Ixc::Client.new(active_erp_connection)
  end

  def ixc_lookups
    @ixc_lookups ||= Ibsoft::Erp::Adapters::Ixc::Lookups.new(ixc_client)
  end

  def filter_attributes
    return {} unless params[:filters].respond_to?(:to_unsafe_h)

    params[:filters].to_unsafe_h
  end

  def collection_param(name)
    raw_value = params[name]
    return [] if raw_value.blank?
    return raw_value.to_unsafe_h.values if raw_value.respond_to?(:to_unsafe_h)

    Array(raw_value)
  end

  def permitted_hash(value, keys)
    return value.permit(*keys).to_h.with_indifferent_access if value.respond_to?(:permit)

    value.to_h.with_indifferent_access
  end
end
