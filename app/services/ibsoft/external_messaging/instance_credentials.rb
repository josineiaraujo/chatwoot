class Ibsoft::ExternalMessaging::InstanceCredentials
  def initialize(endpoint:)
    @endpoint = endpoint
  end

  def public_payload
    case authentication_strategy
    when 'username_password'
      {
        type: authentication_strategy,
        username: username,
        secret_hint: endpoint.token_hint
      }
    else
      {
        type: authentication_strategy,
        secret_hint: endpoint.token_hint
      }
    end
  end

  def issued_payload(secret)
    case authentication_strategy
    when 'username_password'
      {
        credentials: {
          type: authentication_strategy,
          username: username,
          password: secret
        }
      }
    else
      { token: secret }
    end
  end

  def username
    return unless authentication_strategy == 'username_password'

    "#{definition.username_prefix}_#{endpoint.id}"
  end

  private

  attr_reader :endpoint

  def authentication_strategy
    definition.authentication_strategy
  end

  def definition
    @definition ||=
      Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(endpoint.instance_type)
  end
end
