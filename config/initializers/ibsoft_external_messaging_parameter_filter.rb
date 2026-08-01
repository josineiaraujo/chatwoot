external_messaging_sensitive_parameters = %w[
  msg
  to
  token
  user
  pw
  dest
  text
  fatura_id
  id_fatura
  reference_id
  message
  mensagem
  description
  descricao
  payment_timestamp
]

Rails.application.config.filter_parameters += external_messaging_sensitive_parameters.map do |name|
  /\A#{Regexp.escape(name)}\z/i
end
