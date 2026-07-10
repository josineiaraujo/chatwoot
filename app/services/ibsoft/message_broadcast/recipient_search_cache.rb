require 'base64'
require 'digest'
require 'securerandom'
require 'zlib'

class Ibsoft::MessageBroadcast::RecipientSearchCache
  class CorruptedSnapshotError < StandardError; end

  CACHE_VERSION = 2
  CHUNK_SIZE = 250
  TTL = 15.minutes.to_i
  BUILD_TTL = 10.minutes.to_i

  def initialize(account:, connection:)
    @account = account
    @connection = connection
  end

  def token_for(mode, filters)
    Digest::SHA256.hexdigest(
      [CACHE_VERSION, account.id, connection.id, connection.updated_at.to_f, mode.to_s, canonical_json(filters)].join(':')
    )
  end

  def metadata(token)
    raw_metadata = Redis::Alfred.get(metadata_key(token))
    return if raw_metadata.blank?

    JSON.parse(raw_metadata)
  rescue JSON::ParserError
    invalidate(token)
    nil
  end

  def acquire_build_lock(token)
    lock_token = SecureRandom.uuid
    acquired = Redis::Alfred.set(lock_key(token), lock_token, nx: true, ex: BUILD_TTL)
    acquired ? lock_token : nil
  end

  def lock_owned?(token, lock_token)
    Redis::Alfred.get(lock_key(token)) == lock_token
  end

  def release_build_lock(token, lock_token)
    Redis::Alfred.delete_if_equals(lock_key(token), lock_token)
  end

  def mark_building(token)
    write_metadata(token, status: 'building', started_at: Time.current.iso8601)
  end

  def mark_failed(token, error_code:)
    write_metadata(
      token,
      status: 'failed',
      error_code: error_code,
      failed_at: Time.current.iso8601
    )
  end

  def write(token, snapshot)
    customers = Array(snapshot[:customers] || snapshot['customers']).map(&:deep_stringify_keys)
    chunks = customers.each_slice(CHUNK_SIZE).to_a
    write_chunks(token, chunks)
    write_metadata(
      token,
      status: 'ready',
      total: customers.size,
      chunk_count: chunks.size,
      source_total: snapshot[:source_total] || snapshot['source_total'],
      source_returned: snapshot[:source_returned] || snapshot['source_returned'],
      generated_at: Time.current.iso8601
    )
  end

  def page(token:, page:, per_page:, query: nil)
    ready_metadata = metadata(token)
    raise CorruptedSnapshotError unless ready_metadata&.fetch('status', nil) == 'ready'

    query.present? ? searched_page(token, ready_metadata, page, per_page, query) : cached_page(token, ready_metadata, page, per_page)
  end

  def invalidate(token)
    raw_metadata = Redis::Alfred.get(metadata_key(token))
    chunk_count = JSON.parse(raw_metadata).fetch('chunk_count', 0).to_i if raw_metadata.present?
    Redis::Alfred.delete(metadata_key(token))
    Array.new(chunk_count.to_i) { |index| Redis::Alfred.delete(chunk_key(token, index)) }
  rescue JSON::ParserError
    Redis::Alfred.delete(metadata_key(token))
  end

  private

  attr_reader :account, :connection

  def canonical_json(value)
    JSON.generate(canonical_value(value))
  end

  def canonical_value(value)
    case value
    when Hash, ActionController::Parameters
      value.to_h.deep_stringify_keys.sort.to_h.transform_values { |item| canonical_value(item) }
    when Array
      value.map { |item| canonical_value(item) }.sort_by(&:to_s)
    else
      value
    end
  end

  def write_chunks(token, chunks)
    Redis::Alfred.pipelined do |pipeline|
      chunks.each_with_index do |chunk, index|
        pipeline.set(chunk_key(token, index), encode(chunk), ex: TTL)
      end
    end
  end

  def write_metadata(token, metadata)
    status = metadata[:status] || metadata['status']
    Redis::Alfred.set(metadata_key(token), metadata.to_json, ex: status == 'ready' ? TTL : BUILD_TTL)
  end

  def cached_page(token, metadata, page, per_page)
    total = metadata.fetch('total').to_i
    offset = (page - 1) * per_page
    return page_result([], total) if offset >= total

    first_chunk = offset / CHUNK_SIZE
    last_chunk = [((offset + per_page - 1) / CHUNK_SIZE), metadata.fetch('chunk_count').to_i - 1].min
    customers = read_chunks(token, (first_chunk..last_chunk).to_a)
    local_offset = offset - (first_chunk * CHUNK_SIZE)

    page_result(customers.slice(local_offset, per_page) || [], total)
  end

  def searched_page(token, metadata, page, per_page, query)
    customers = read_chunks(token, (0...metadata.fetch('chunk_count').to_i).to_a)
    normalized_query = normalize_search_value(query)
    matches = customers.select { |customer| searchable_values(customer).any? { |value| value.include?(normalized_query) } }
    offset = (page - 1) * per_page

    page_result(matches.slice(offset, per_page) || [], matches.size)
  end

  def read_chunks(token, indexes)
    return [] if indexes.empty?

    keys = indexes.map { |index| chunk_key(token, index) }
    encoded_chunks = Redis::Alfred.with { |connection| connection.mget(*keys) }
    raise CorruptedSnapshotError if encoded_chunks.any?(&:blank?)

    encoded_chunks.flat_map { |encoded_chunk| decode(encoded_chunk) }
  rescue ArgumentError, JSON::ParserError, Zlib::Error
    raise CorruptedSnapshotError
  end

  def searchable_values(customer)
    phone_selection = customer.fetch('phone_selection', {})
    %w[external_id name document address neighborhood city_name state zip_code].filter_map do |field|
      normalize_search_value(customer[field]).presence
    end.concat(
      %w[primary_phone fallback_phone].filter_map do |field|
        normalize_search_value(phone_selection[field]).presence
      end
    )
  end

  def normalize_search_value(value)
    I18n.transliterate(value.to_s).downcase.strip
  end

  def page_result(customers, total)
    {
      customers: customers.map { |customer| customer.except('_search') },
      total: total
    }
  end

  def encode(value)
    Base64.strict_encode64(Zlib::Deflate.deflate(value.to_json))
  end

  def decode(value)
    JSON.parse(Zlib::Inflate.inflate(Base64.strict_decode64(value)))
  end

  def base_key(token)
    "ibsoft:message_broadcast:recipient_search:#{account.id}:#{connection.id}:#{token}"
  end

  def metadata_key(token)
    "#{base_key(token)}:meta"
  end

  def chunk_key(token, index)
    "#{base_key(token)}:chunk:#{index}"
  end

  def lock_key(token)
    "#{base_key(token)}:lock"
  end
end
