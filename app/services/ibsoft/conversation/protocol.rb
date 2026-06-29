class Ibsoft::Conversation::Protocol
  PATTERN = /\A(\d{4})(\d{2})(\d{2})-(\d+)-(\d+)\z/
  SECONDS_PER_DAY = 86_400

  def self.match?(protocol)
    protocol.to_s.strip.match?(PATTERN)
  end

  def self.parse(protocol)
    match = protocol.to_s.strip.match(PATTERN)
    return unless match

    date = Date.iso8601("#{match[1]}-#{match[2]}-#{match[3]}")
    return unless date.strftime('%Y%m%d') == "#{match[1]}#{match[2]}#{match[3]}"

    {
      date: date,
      account_id: match[4].to_i,
      conversation_id: match[5].to_i
    }
  rescue ArgumentError
    nil
  end

  def self.utc_day_range(date)
    starts_at = Time.utc(date.year, date.month, date.day)
    starts_at...(starts_at + SECONDS_PER_DAY)
  end
end
