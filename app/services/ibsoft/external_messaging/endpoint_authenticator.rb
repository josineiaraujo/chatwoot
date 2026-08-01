require 'digest'

class Ibsoft::ExternalMessaging::EndpointAuthenticator
  def initialize(credentials:, instance_type: nil, family: nil)
    @instance_type = instance_type.to_s.presence
    @family = family.to_s.presence
    @credentials = credentials.to_h.deep_symbolize_keys
    raise ArgumentError, 'provide exactly one endpoint scope' unless [@instance_type, @family].compact.one?
  end

  def call
    endpoint = Ibsoft::ExternalMessaging::Endpoint.authenticate(secret)
    raise_unauthorized unless endpoint_matches_scope?(endpoint)
    raise_unauthorized unless username_valid?(endpoint)

    endpoint
  end

  private

  attr_reader :instance_type, :family, :credentials

  def definition
    @definition ||= if instance_type
                      Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(instance_type)
                    else
                      Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch_family(family)
                    end
  end

  def endpoint_matches_scope?(endpoint)
    return false if endpoint.blank?
    return endpoint.instance_type == instance_type if instance_type

    endpoint_definition(endpoint).family == family
  end

  def secret
    if definition.authentication_strategy == 'username_password'
      credentials[:password]
    else
      credentials[:token]
    end
  end

  def username_valid?(endpoint)
    return true unless endpoint_definition(endpoint).authentication_strategy == 'username_password'

    expected = Ibsoft::ExternalMessaging::InstanceCredentials.new(endpoint: endpoint).username
    secure_compare(credentials[:username], expected)
  end

  def secure_compare(value, expected)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(value.to_s),
      Digest::SHA256.hexdigest(expected.to_s)
    )
  end

  def endpoint_definition(endpoint)
    Ibsoft::ExternalMessaging::InstanceTypeRegistry.fetch(endpoint.instance_type)
  end

  def raise_unauthorized
    code = definition.authentication_strategy == 'username_password' ? 'ixc_unauthorized' : 'unauthorized'
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, http_status: :unauthorized)
  end
end
