class Ibsoft::AgentProvisioning::TemporaryPasswordGenerator
  REQUIRED_SUFFIX = '1!aA'.freeze

  def self.generate
    "#{SecureRandom.alphanumeric(18)}#{REQUIRED_SUFFIX}"
  end
end
