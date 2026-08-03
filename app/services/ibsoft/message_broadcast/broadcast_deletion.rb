class Ibsoft::MessageBroadcast::BroadcastDeletion
  Result = Data.define(:deleted_ids, :blocked_ids, :missing_ids) do
    def success? = blocked_ids.empty? && missing_ids.empty?
  end

  def initialize(scope:, ids:)
    @scope = scope
    @ids = Array(ids).filter_map { |id| Integer(id, exception: false) }.select(&:positive?).uniq
  end

  def call
    result = nil

    Ibsoft::MessageBroadcast::Broadcast.transaction do
      records = locked_records
      result = deletion_result(records)
      delete_records(records) if result.success?
    end

    result
  end

  private

  attr_reader :scope, :ids

  def locked_records
    scope.where(id: ids).order(:id).lock.to_a
  end

  def deletion_result(records)
    record_ids = records.map(&:id)
    blocked_ids = records.reject(&:deletable?).map(&:id)
    missing_ids = ids - record_ids
    deleted_ids = blocked_ids.empty? && missing_ids.empty? ? record_ids : []

    Result.new(
      deleted_ids: deleted_ids,
      blocked_ids: blocked_ids,
      missing_ids: missing_ids
    )
  end

  def delete_records(records)
    record_ids = records.map(&:id)
    Ibsoft::MessageBroadcast::Recipient.where(broadcast_id: record_ids).delete_all
    scope.where(id: record_ids).delete_all
  end
end
