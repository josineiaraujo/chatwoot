class Api::V1::Accounts::Ibsoft::ExternalMessaging::DeliveriesController <
  Api::V1::Accounts::Ibsoft::ExternalMessaging::BaseController
  PER_PAGE = 25
  MAX_PER_PAGE = 100

  def index
    deliveries = filtered_deliveries
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)

    render json: {
      deliveries: deliveries.offset((page - 1) * per_page).limit(per_page).map(&:payload),
      meta: {
        page: page,
        per_page: per_page,
        total: deliveries.count
      }
    }
  end

  def show
    delivery = scoped_deliveries.find(params[:id])

    render json: delivery.payload
  end

  private

  def scoped_deliveries
    Ibsoft::ExternalMessaging::Delivery
      .where(account: Current.account)
      .includes(:endpoint, :inbox)
      .latest_first
  end

  def filtered_deliveries
    scope = scoped_deliveries
    scope = scope.where(endpoint_id: params[:endpoint_id]) if params[:endpoint_id].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope
  end
end
