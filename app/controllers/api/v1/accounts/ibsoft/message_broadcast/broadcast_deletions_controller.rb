class Api::V1::Accounts::Ibsoft::MessageBroadcast::BroadcastDeletionsController < Api::V1::Accounts::Ibsoft::MessageBroadcast::BaseController
  before_action :set_broadcast, only: :destroy

  def destroy
    result = delete_broadcasts([@broadcast.id])
    return render_deletion_error(result) unless result.success?

    head :no_content
  end

  def bulk_destroy
    ids = deletion_ids
    return render_invalid_selection if ids.empty?

    result = delete_broadcasts(ids)
    return render_deletion_error(result) unless result.success?

    render json: { deleted_ids: result.deleted_ids }
  end

  private

  def deletion_scope
    Ibsoft::MessageBroadcast::Broadcast.where(account: Current.account)
  end

  def set_broadcast
    @broadcast = deletion_scope.find(params[:id])
  end

  def deletion_ids
    normalized_ids = Array(params.permit(ids: [])[:ids]).map do |id|
      Integer(id, exception: false)
    end
    return [] if normalized_ids.any? { |id| id.nil? || !id.positive? }

    normalized_ids.uniq
  end

  def delete_broadcasts(ids)
    Ibsoft::MessageBroadcast::BroadcastDeletion.new(
      scope: deletion_scope,
      ids: ids
    ).call
  end

  def render_deletion_error(result)
    return render_broadcast_in_progress(result.blocked_ids) if result.blocked_ids.any?

    render_invalid_selection
  end

  def render_broadcast_in_progress(blocked_ids)
    render json: {
      error: 'broadcast_in_progress',
      blocked_ids: blocked_ids
    }, status: :unprocessable_content
  end

  def render_invalid_selection
    render json: { error: 'invalid_broadcast_selection' }, status: :unprocessable_content
  end
end
