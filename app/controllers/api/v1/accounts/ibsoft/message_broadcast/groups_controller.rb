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

    group = Ibsoft::MessageBroadcast::Group.new(group_attributes)
    group.account = Current.account
    group.created_by = Current.user
    group.erp_provider = active_erp_connection.provider
    group.save!
    sync_members(group) if params.key?(:members)

    render json: group_payload(group.reload)
  end

  def update
    @group.update!(group_attributes.slice(:name, :description))
    sync_members(@group) if params.key?(:members)

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

  def sync_members(group)
    group.members.destroy_all
    member_attributes.each do |attributes|
      group.members.create!(attributes)
    end
  end

  def member_attributes
    collection_param(:members).filter_map { |member| member_payload(member) }
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
