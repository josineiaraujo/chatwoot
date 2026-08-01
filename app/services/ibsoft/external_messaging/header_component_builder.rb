class Ibsoft::ExternalMessaging::HeaderComponentBuilder
  ALIASES = {
    'header.type' => 'header_type',
    'header.link' => 'header_link',
    'header.text' => 'header_text',
    'header.filename' => 'header_filename',
    'header.pdf_mode' => 'header_pdf_mode',
    'header.append_pdf' => 'header_append_pdf'
  }.freeze
  TYPES = %w[text document image video].freeze

  def initialize(fields:)
    @fields = fields
  end

  def call
    validate_field_names!
    return if header_fields.empty?

    type = aliased_value('header.type').downcase
    link = aliased_value('header.link')
    text, parameter_name = text_variable
    type = infer_type(link) if type.blank?

    return build_text(text, link, parameter_name) if type == 'text'

    build_media(type, link, parameter_name)
  end

  private

  attr_reader :fields

  def header_fields
    @header_fields ||= fields.select do |name, _value|
      name.start_with?('header.') || ALIASES.value?(name)
    end
  end

  def validate_field_names!
    allowed = ALIASES.keys + ALIASES.values + ['header.parameter_name']
    invalid = header_fields.keys.find do |name|
      allowed.exclude?(name) && !name.match?(/\Aheader\.variable\.(?:1|[A-Za-z_][A-Za-z0-9_]*)\z/)
    end
    raise_error('unsupported_field', field: invalid) if invalid
  end

  def text_variable
    variables = fields.select { |name, _value| name.start_with?('header.variable.') }
    text = aliased_value('header.text')
    parameter_name = fields['header.parameter_name'].to_s.strip

    validate_text_variables!(variables, text, parameter_name)

    return [text, parameter_name] if variables.empty?

    variable_value(variables.first)
  end

  def validate_text_variables!(variables, text, parameter_name)
    configured_twice = variables.present? && (text.present? || parameter_name.present?)
    raise_error('header_variable_conflict') if configured_twice
    raise_error('header_too_many_variables') if variables.many?
  end

  def variable_value(variable)
    name, value = variable
    variable_name = name.delete_prefix('header.variable.')
    raise_error('field_required', field: name) if value.to_s.strip.blank?

    [value.to_s, variable_name == '1' ? '' : variable_name]
  end

  def build_text(text, link, parameter_name)
    raise_error('header_text_required') if text.blank?
    raise_error('header_text_with_link') if link.present?
    raise_error('header_text_with_document_options') if document_options?

    parameter = { type: 'text', text: text }
    if parameter_name.present?
      parameter[:parameter_name] = Ibsoft::ExternalMessaging::ValueCoercion.parameter_name(
        parameter_name,
        field: 'header.parameter_name'
      )
    end
    { type: 'header', parameters: [parameter] }
  end

  def build_media(type, link, parameter_name)
    raise_error('header_type_invalid') unless type.in?(TYPES - ['text'])
    raise_error('header_link_required') if link.blank?
    raise_error('header_parameter_name_media') if parameter_name.present?

    validated_link = Ibsoft::ExternalMessaging::ValueCoercion.https_url(link, field: 'header.link')
    return build_document(validated_link) if type == 'document'

    raise_error('header_media_with_document_options') if document_options?

    parameter = { type: type }
    parameter[type.to_sym] = { link: validated_link }
    { type: 'header', parameters: [parameter] }
  end

  def build_document(link)
    link = apply_pdf_mode(link)
    filename = aliased_value('header.filename').presence || filename_from(link)
    raise_error('header_filename_invalid') if filename.bytesize > 240 || filename.match?(%r{[/\\\x00-\x1F\x7F]})

    {
      type: 'header',
      parameters: [{ type: 'document', document: { link: link, filename: filename } }]
    }
  end

  def document_options?
    %w[header.filename header.pdf_mode header.append_pdf].any? do |name|
      aliased_value(name).present?
    end
  end

  def apply_pdf_mode(link)
    mode = resolved_pdf_mode
    return link if mode == 'as_is' || URI.parse(link).path.to_s.downcase.end_with?('.pdf')

    append_pdf_extension(link)
  end

  def resolved_pdf_mode
    mode = aliased_value('header.pdf_mode').downcase
    append = aliased_value('header.append_pdf')
    if append.present?
      append_mode = pdf_append_mode(append)
      raise_error('header_pdf_options_conflict') if mode.present? && mode != append_mode

      mode = append_mode
    end
    mode = 'as_is' if mode.blank?
    raise_error('header_pdf_mode_invalid') unless mode.in?(%w[as_is append])
    mode
  end

  def pdf_append_mode(value)
    append = Ibsoft::ExternalMessaging::ValueCoercion.boolean(
      value,
      field: 'header.append_pdf'
    )
    append ? 'append' : 'as_is'
  end

  def append_pdf_extension(link)
    uri = URI.parse(link)
    uri.path = "#{uri.path.to_s.delete_suffix('/')}.pdf"
    uri.to_s
  end

  def infer_type(link)
    return 'text' if link.blank?

    path = URI.parse(link).path.to_s.downcase
    return 'document' if path.end_with?('.pdf')
    return 'image' if path.match?(/\.(?:jpe?g|png|webp)\z/)
    return 'video' if path.match?(/\.(?:mp4|3gp)\z/)

    raise_error('header_type_required')
  rescue URI::InvalidURIError
    raise_error('https_url_invalid', field: 'header.link')
  end

  def filename_from(link)
    filename = CGI.unescape(File.basename(URI.parse(link).path.to_s))
    filename.in?(['', '/', '.']) ? 'documento.pdf' : filename
  end

  def aliased_value(primary)
    alias_name = ALIASES[primary]
    primary_value = fields[primary].to_s.strip
    alias_value = fields[alias_name].to_s.strip
    if primary_value.present? && alias_value.present? && primary_value != alias_value
      raise_error('alias_conflict', primary: primary, alias: alias_name)
    end

    primary_value.presence || alias_value
  end

  def raise_error(code, **)
    raise Ibsoft::ExternalMessaging::InvalidRequest.new(code, **)
  end
end
