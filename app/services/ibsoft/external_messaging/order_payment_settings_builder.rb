class Ibsoft::ExternalMessaging::OrderPaymentSettingsBuilder
  PIX_KEY_TYPES = %w[CPF CNPJ EMAIL PHONE EVP].freeze

  def initialize(fields:)
    @fields = fields
  end

  def call
    settings = []
    pix_code = fields['order.payment.pix.code'].to_s.strip
    settings << pix_setting(pix_code) if pix_code.present?

    digitable_line = fields['order.payment.boleto.digitable_line'].to_s.strip
    settings << boleto_setting(digitable_line) if digitable_line.present?
    raise_error('order_payment_required') if settings.empty?

    settings
  end

  private

  attr_reader :fields

  def pix_setting(code)
    key_type = required('order.payment.pix.key_type').upcase
    raise_error('pix_key_type_invalid') unless key_type.in?(PIX_KEY_TYPES)

    {
      type: 'pix_dynamic_code',
      pix_dynamic_code: {
        code: code,
        merchant_name: required('order.payment.pix.merchant_name'),
        key: required('order.payment.pix.key'),
        key_type: key_type
      }
    }
  end

  def boleto_setting(digitable_line)
    {
      type: 'boleto',
      boleto: { digitable_line: digitable_line }
    }
  end

  def required(field)
    value = fields[field].to_s.strip
    raise_error('field_required', field: field) if value.blank?

    value
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end
