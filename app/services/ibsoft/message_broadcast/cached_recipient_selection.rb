class Ibsoft::MessageBroadcast::CachedRecipientSelection
  class SnapshotUnavailableError < StandardError; end

  def initialize(account:, connection:)
    @cache = Ibsoft::MessageBroadcast::RecipientSearchCache.new(account: account, connection: connection)
  end

  def call(token:, query: nil)
    raise SnapshotUnavailableError if token.blank?

    snapshot = cache.metadata(token)
    raise SnapshotUnavailableError unless snapshot&.fetch('status', nil) == 'ready'

    cache.page(
      token: token,
      page: 1,
      per_page: [snapshot.fetch('total').to_i, 1].max,
      query: query
    ).fetch(:customers)
  rescue Ibsoft::MessageBroadcast::RecipientSearchCache::CorruptedSnapshotError
    raise SnapshotUnavailableError
  end

  private

  attr_reader :cache
end
