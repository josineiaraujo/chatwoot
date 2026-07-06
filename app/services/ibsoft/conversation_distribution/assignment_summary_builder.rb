class Ibsoft::ConversationDistribution::AssignmentSummaryBuilder
  def self.build(results)
    {
      scanned: results.length,
      assigned: results.count { |result| result[:status] == 'assigned' },
      skipped: results.count { |result| result[:status] == 'skipped' },
      ignored: results.count { |result| result[:status] == 'ignored' },
      by_reason: results.pluck(:reason).tally
    }
  end
end
