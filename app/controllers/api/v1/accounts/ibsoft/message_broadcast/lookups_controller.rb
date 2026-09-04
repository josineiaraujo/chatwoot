class Api::V1::Accounts::Ibsoft::MessageBroadcast::LookupsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  before_action :ensure_active_erp_connection!
  before_action :ensure_supported_erp_provider!

  def capabilities
    render json: {
      provider: active_erp_connection.provider,
      connection: active_erp_connection.slice(:id, :name, :provider),
      capabilities: Ibsoft::Erp::Adapters::Registry.capabilities(active_erp_connection.provider)
    }
  end

  def states
    render json: {
      states: erp_lookups.states(query: params[:query], limit: lookup_limit)
    }
  end

  def cities
    render json: {
      cities: erp_lookups.cities(
        state_id: params[:state_id],
        query: params[:query],
        limit: lookup_limit
      )
    }
  end

  def plans
    render json: {
      plans: erp_lookups.plans(
        query: params[:query],
        active: active_filter,
        limit: lookup_limit
      )
    }
  end

  def pops
    render json: {
      pops: erp_lookups.pops(
        query: params[:query],
        limit: lookup_limit
      )
    }
  end

  def transmitters
    render json: {
      transmitters: erp_lookups.transmitters(
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
