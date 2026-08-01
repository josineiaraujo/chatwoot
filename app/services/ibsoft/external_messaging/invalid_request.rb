class Ibsoft::ExternalMessaging::InvalidRequest < StandardError
  attr_reader :code, :http_status

  def initialize(code, http_status: 422, **)
    @code = code.to_s
    @http_status = http_status
    super(
      I18n.t(
        "ibsoft_external_messaging.errors.#{@code}",
        **,
        default: I18n.t('ibsoft_external_messaging.errors.invalid_request')
      )
    )
  end
end
