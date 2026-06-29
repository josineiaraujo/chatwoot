class Ibsoft::Conversation::ProtocolFilterPayload
  ATTRIBUTE_KEY = 'ibsoft_protocol'.freeze
  NO_MATCH_DISPLAY_ID = -1

  def initialize(params:, account_id:)
    @params = params
    @account_id = account_id.to_i
  end

  def perform
    payload = Array(params_hash[:payload])
    return params_hash unless payload.any? { |condition| protocol_filter?(condition) }

    params_hash.merge(payload: expand_payload(payload)).with_indifferent_access
  end

  private

  def params_hash
    @params_hash ||= if @params.respond_to?(:to_unsafe_h)
                       @params.to_unsafe_h.with_indifferent_access
                     else
                       @params.to_h.with_indifferent_access
                     end
  end

  def expand_payload(payload)
    payload.flat_map do |condition|
      condition = condition.with_indifferent_access
      next condition unless protocol_filter?(condition)

      expand_protocol_condition(condition)
    end
  end

  def protocol_filter?(condition)
    condition['attribute_key'] == ATTRIBUTE_KEY
  end

  def expand_protocol_condition(condition)
    parsed_protocol = parse_protocol(Array(condition['values']).first)
    return [no_match_condition(condition)] unless parsed_protocol
    return [no_match_condition(condition)] unless parsed_protocol[:account_id] == @account_id

    [
      display_id_condition(condition, parsed_protocol[:conversation_id], 'and'),
      created_at_condition(
        condition,
        'is_greater_than',
        parsed_protocol[:date] - 1,
        'and'
      ),
      created_at_condition(
        condition,
        'is_less_than',
        parsed_protocol[:date] + 1,
        condition['query_operator']
      )
    ]
  end

  def parse_protocol(protocol)
    Ibsoft::Conversation::Protocol.parse(protocol)
  end

  def no_match_condition(condition)
    display_id_condition(
      condition,
      NO_MATCH_DISPLAY_ID,
      condition['query_operator']
    )
  end

  def display_id_condition(condition, display_id, query_operator)
    condition.merge(
      'attribute_key' => 'display_id',
      'filter_operator' => 'equal_to',
      'values' => [display_id],
      'query_operator' => query_operator
    )
  end

  def created_at_condition(condition, operator, date, query_operator)
    condition.merge(
      'attribute_key' => 'created_at',
      'filter_operator' => operator,
      'values' => [date.iso8601],
      'query_operator' => query_operator
    )
  end
end
