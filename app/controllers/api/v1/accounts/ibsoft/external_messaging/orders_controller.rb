class Api::V1::Accounts::Ibsoft::ExternalMessaging::OrdersController <
  Api::V1::Accounts::Ibsoft::ExternalMessaging::BaseController
  PER_PAGE = 25
  MAX_PER_PAGE = 100

  before_action :set_endpoint

  def index
    scope = filtered_orders
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    orders = scope
             .includes(:updates, opening_delivery: [:endpoint, :inbox])
             .offset((page - 1) * per_page)
             .limit(per_page)

    render json: {
      orders: orders.map(&:dashboard_payload),
      meta: {
        page: page,
        per_page: per_page,
        total: scope.count,
        updateable_total: scope.manually_updateable.count
      }
    }
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    render_error(e)
  end

  def bulk_update
    result = Ibsoft::ExternalMessaging::BulkOrderUpdateScheduler.new(
      account: Current.account,
      endpoint: @endpoint,
      user: Current.user,
      params: params.permit(
        selection: [:mode, { ids: [] }],
        filters: Ibsoft::ExternalMessaging::OrdersQuery::FILTER_KEYS,
        update: [:order_status, :payment_status]
      )
    ).call

    render json: {
      accepted: true,
      count: result.matched_count
    }, status: :accepted
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    render_error(e)
  end

  private

  def set_endpoint
    @endpoint = Ibsoft::ExternalMessaging::Endpoint
                .where(account: Current.account)
                .find(params[:endpoint_id])
  end

  def filtered_orders
    Ibsoft::ExternalMessaging::OrdersQuery.new(
      account: Current.account,
      endpoint: @endpoint,
      filters: params.permit(*Ibsoft::ExternalMessaging::OrdersQuery::FILTER_KEYS)
    ).call
  end

  def render_error(error)
    render json: {
      error: {
        code: error.code,
        message: error.message
      }
    }, status: error.http_status
  end
end
