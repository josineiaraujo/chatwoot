class Api::V1::Accounts::Ibsoft::MessageBroadcast::GroupsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  MEMBER_KEYS = [:external_customer_id, :customer_name, :name, :primary_phone, :fallback_phone, :city, :state, :active].freeze

  before_action :set_group, only: [:show, :update, :destroy]

  def index
    render json: {
      groups: scoped_groups.map(&:payload)
    }
  end

  def show
    render json: group_payload(@group)
  end

  def create
    return unless ensure_active_erp_connection!

    group = nil
    members = requested_member_attributes
    Ibsoft::MessageBroadcast::Group.transaction do
      group = Ibsoft::MessageBroadcast::Group.new(group_attributes)
      group.account = Current.account
      group.created_by = Current.user
      group.erp_provider = active_erp_connection.provider
      group.save!
      sync_members(group, members) if params.key?(:members) || params.key?(:selection)
    end

    render json: group_payload(group.reload)
  rescue Ibsoft::MessageBroadcast::CachedRecipientSelection::SnapshotUnavailableError
    render json: { error: 'recipient_selection_expired' }, status: :unprocessable_content
  end

  def update
    Ibsoft::MessageBroadcast::Group.transaction do
      @group.update!(group_attributes.slice(:name, :description))
      sync_members(@group) if params.key?(:members)
    end

    render json: group_payload(@group.reload)
  end

  def destroy
    @group.destroy!

    head :no_content
  end

  private

  def scoped_groups
    Ibsoft::MessageBroadcast::Group.where(account: Current.account).order(updated_at: :desc)
  end

  def set_group
    @group = scoped_groups.find(params[:id])
  end

  def group_attributes
    params.permit(:name, :description).to_h
  end

  def group_payload(group)
    group.payload.merge(
      members: group.members.order(:customer_name).map(&:payload)
    )
  end

  def sync_members(group, attributes = member_attributes)
    group.members.delete_all
    unique_attributes = attributes.index_by { |member| member[:external_customer_id] }.values
    members = unique_attributes.map { |member| group.members.build(member) }
    Ibsoft::MessageBroadcast::GroupMember.import!(members, batch_size: 500)
  end

  def member_attributes
    collection_param(:members).filter_map { |member| member_payload(member) }
  end

  def requested_member_attributes
    return member_attributes if params.key?(:members)
    return [] unless params.key?(:selection)

    selection = params.require(:selection).permit(:scope, :search_token, :query)
    return [] unless selection[:scope] == 'all'

    cached_customers(selection).filter_map { |customer| cached_customer_payload(customer) }
  end

  def cached_customers(selection)
    Ibsoft::MessageBroadcast::CachedRecipientSelection.new(
      account: Current.account,
      connection: active_erp_connection
    ).call(token: selection[:search_token], query: selection[:query])
  end

  def cached_customer_payload(customer)
    phone_selection = customer.fetch('phone_selection', {})
    member_payload(
      external_customer_id: customer['external_id'],
      customer_name: customer['name'],
      primary_phone: phone_selection['primary_phone'],
      fallback_phone: phone_selection['fallback_phone'],
      city: customer['city_name'],
      state: customer['state'],
      active: customer.fetch('active', true)
    )
  end

  def member_payload(member)
    normalized_member = permitted_hash(member, MEMBER_KEYS)
    return if normalized_member[:external_customer_id].blank?

    {
      external_customer_id: normalized_member[:external_customer_id],
      customer_name: normalized_member[:customer_name].presence || normalized_member[:name],
      primary_phone: normalized_member[:primary_phone],
      fallback_phone: normalized_member[:fallback_phone],
      city: normalized_member[:city],
      state: normalized_member[:state],
      active: ActiveModel::Type::Boolean.new.cast(normalized_member.fetch(:active, true))
    }
  end
end
