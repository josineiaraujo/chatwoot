class Ibsoft::ConversationDistribution::EventLogFinder
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 100
  DEFAULT_PAGE = 1
  EXACT_FILTER_KEYS = %w[
    event_type
    reason
    inbox_id
    team_id
    previous_assignee_id
    new_assignee_id
  ].freeze

  def initialize(account:, filters: {})
    @account = account
    @filters = filters.to_h.deep_stringify_keys
  end

  def perform
    {
      generated_at: Time.current.iso8601,
      filters: normalized_filters,
      pagination: pagination_payload,
      summary: summary_payload,
      events: paginated_events.map { |event| event_payload(event) }
    }
  end

  private

  attr_reader :account, :filters

  def paginated_events
    @paginated_events ||= filtered_scope
                          .order(created_at: :desc, id: :desc)
                          .offset((page - 1) * limit)
                          .limit(limit)
                          .to_a
  end

  def filtered_scope
    @filtered_scope ||= begin
      scope = base_scope
      scope = apply_exact_filters(scope)
      scope = apply_conversation_filter(scope)
      apply_time_filters(scope)
    end
  end

  def base_scope
    Ibsoft::ConversationDistribution::EventLog
      .where(account: account)
      .includes(:inbox, :team, :previous_assignee, :new_assignee, conversation: :contact)
  end

  def apply_exact_filters(scope)
    EXACT_FILTER_KEYS.reduce(scope) do |current_scope, key|
      filters[key].present? ? current_scope.where(key => filters[key]) : current_scope
    end
  end

  def apply_conversation_filter(scope)
    return scope if filters['conversation_id'].blank?
    return scope.none if conversation_filter_value.blank?

    scope.where(conversation_id: visible_conversation_ids.presence || conversation_filter_value)
  end

  def apply_time_filters(scope)
    scope = scope.where(created_at: since_time..) if since_time.present?
    scope = scope.where(created_at: ..until_time) if until_time.present?

    scope
  end

  def total_count
    @total_count ||= filtered_scope.count
  end

  def event_payload(event)
    {
      id: event.id,
      event_type: event.event_type,
      reason: event.reason,
      metadata: event.metadata || {},
      created_at: event.created_at.iso8601,
      conversation: conversation_payload(event.conversation),
      inbox: resource_payload(event.inbox),
      team: resource_payload(event.team),
      previous_assignee: user_payload(event.previous_assignee),
      new_assignee: user_payload(event.new_assignee)
    }
  end

  def conversation_payload(conversation)
    return if conversation.blank?

    {
      id: conversation.id,
      display_id: conversation.display_id,
      status: conversation.status,
      contact: contact_payload(conversation.contact)
    }
  end

  def contact_payload(contact)
    return if contact.blank?

    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number
    }
  end

  def resource_payload(resource)
    return if resource.blank?

    {
      id: resource.id,
      name: resource.name
    }
  end

  def user_payload(user)
    return if user.blank?

    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def pagination_payload
    {
      page: page,
      limit: limit,
      total_count: total_count,
      total_pages: total_pages,
      next_page: page < total_pages ? page + 1 : nil,
      previous_page: page > DEFAULT_PAGE ? page - 1 : nil
    }
  end

  def summary_payload
    {
      total: total_count,
      by_event_type: filtered_scope.group(:event_type).count,
      by_reason: filtered_scope.group(:reason).count.compact
    }
  end

  def normalized_filters
    filters.slice(
      'event_type',
      'reason',
      'conversation_id',
      'inbox_id',
      'team_id',
      'previous_assignee_id',
      'new_assignee_id',
      'since',
      'until'
    ).compact_blank
  end

  def total_pages
    return 1 if total_count.zero?

    (total_count.to_f / limit).ceil
  end

  def page
    requested_page = filters['page'].to_i
    requested_page.positive? ? requested_page : DEFAULT_PAGE
  end

  def limit
    requested_limit = filters['limit'].to_i
    requested_limit = DEFAULT_LIMIT unless requested_limit.positive?

    [requested_limit, MAX_LIMIT].min
  end

  def since_time
    @since_time ||= parse_time(filters['since'])
  end

  def until_time
    @until_time ||= parse_time(filters['until'])
  end

  def parse_time(value)
    return if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def conversation_filter_value
    raw_value = filters['conversation_id'].to_s.strip.delete_prefix('#')
    return unless raw_value.match?(/\A\d+\z/)

    raw_value.to_i
  end

  def visible_conversation_ids
    @visible_conversation_ids ||= account.conversations.where(display_id: conversation_filter_value).pluck(:id)
  end
end
