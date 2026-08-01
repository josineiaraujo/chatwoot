class Ibsoft::ExternalMessaging::InstanceTypeRegistry
  Definition = Struct.new(
    :family,
    :public_path,
    :order_update_path,
    :authentication_strategy,
    :username_prefix,
    :request_parser_class,
    :request_contract_class,
    keyword_init: true
  )

  TYPES = {
    'sgp_generic' => Definition.new(
      family: 'sgp',
      public_path: '/chathub-sender/sgp/generico/',
      order_update_path: '/chathub-sender/sgp/pedido/',
      authentication_strategy: 'token',
      username_prefix: nil,
      request_parser_class: Ibsoft::ExternalMessaging::InboundRequestParser,
      request_contract_class: Ibsoft::ExternalMessaging::RequestContract
    ),
    'ixc' => Definition.new(
      family: 'ixc',
      public_path: '/chathub-sender/ixc/',
      order_update_path: '/chathub-sender/ixc/pedido/',
      authentication_strategy: 'username_password',
      username_prefix: 'ixc',
      request_parser_class: Ibsoft::ExternalMessaging::IxcInboundRequestParser,
      request_contract_class: Ibsoft::ExternalMessaging::RequestContract
    )
  }.freeze

  class << self
    def keys
      TYPES.keys
    end

    def fetch(instance_type)
      TYPES.fetch(instance_type.to_s)
    end

    def fetch_family(family)
      TYPES.values.find { |definition| definition.family == family.to_s } ||
        raise(KeyError, "unknown external messaging family: #{family}")
    end
  end
end
