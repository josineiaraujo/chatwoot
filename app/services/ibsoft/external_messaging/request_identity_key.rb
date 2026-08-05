class Ibsoft::ExternalMessaging::RequestIdentityKey
  def call
    "request-#{SecureRandom.uuid}"
  end
end
