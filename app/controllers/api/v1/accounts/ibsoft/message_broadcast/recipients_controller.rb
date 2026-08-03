class Api::V1::Accounts::Ibsoft::MessageBroadcast::RecipientsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  before_action :ensure_active_erp_connection!
  before_action :ensure_supported_search_provider!

  def preview
    search_result = Ibsoft::MessageBroadcast::RecipientSearch.new(
      account: Current.account,
      connection: active_erp_connection
    ).call(
      mode: params[:mode],
      filters: filter_attributes,
      pagination: { per_page: params[:limit], page: params[:page] },
      query: params[:query],
      refresh: ActiveModel::Type::Boolean.new.cast(params[:refresh])
    )

    render json: search_result, status: search_result[:status] == 'building' ? :accepted : :ok
  rescue KeyError
    render json: { error: 'invalid_search_mode' }, status: :unprocessable_content
  end

  private

  def ensure_supported_search_provider!
    return true if Ibsoft::MessageBroadcast::RecipientSearch.supports?(active_erp_connection&.provider)

    render json: { error: 'erp_provider_not_supported' }, status: :unprocessable_content
    false
  end
end
