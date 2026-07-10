class Api::V1::Accounts::Ibsoft::MessageBroadcast::LookupsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  before_action :ensure_active_erp_connection!
  before_action :ensure_ixc_provider!

  def states
    render json: {
      states: ixc_lookups.states(query: params[:query], limit: lookup_limit)
    }
  end

  def cities
    render json: {
      cities: ixc_lookups.cities(
        state_id: params[:state_id],
        query: params[:query],
        limit: lookup_limit
      )
    }
  end

  def plans
    render json: {
      plans: ixc_lookups.plans(
        query: params[:query],
        active: active_filter,
        limit: lookup_limit
      )
    }
  end

  def pops
    render json: {
      pops: ixc_lookups.pops(
        query: params[:query],
        limit: lookup_limit
      )
    }
  end

  def transmitters
    render json: {
      transmitters: ixc_lookups.transmitters(
        query: params[:query],
        limit: lookup_limit
      )
    }
  end

  private

  def lookup_limit
    limit = params[:limit].to_i
    return 50 if limit <= 0

    [limit, 100].min
  end

  def active_filter
    return if params[:active].nil?

    ActiveModel::Type::Boolean.new.cast(params[:active])
  end
end
