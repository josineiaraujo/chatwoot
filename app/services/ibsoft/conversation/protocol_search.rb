class Ibsoft::Conversation::ProtocolSearch
  def initialize(scope:, query:, account_id:)
    @scope = scope
    @query = query
    @account_id = account_id.to_i
  end

  def protocol?
    Ibsoft::Conversation::Protocol.match?(@query)
  end

  def perform
    return @scope unless protocol?
    return @scope.none unless parsed_protocol
    return @scope.none unless parsed_protocol[:account_id] == @account_id

    @scope.where(
      display_id: parsed_protocol[:conversation_id],
      created_at: Ibsoft::Conversation::Protocol.utc_day_range(parsed_protocol[:date])
    )
  end

  private

  def parsed_protocol
    @parsed_protocol ||= Ibsoft::Conversation::Protocol.parse(@query)
  end
end
