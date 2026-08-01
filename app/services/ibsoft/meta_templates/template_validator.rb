class Ibsoft::MetaTemplates::TemplateValidator
  def initialize(attributes, for_update:)
    @attributes = attributes.to_h.deep_stringify_keys
    @for_update = for_update
    @errors = []
  end

  def validate!
    validate_common
    validate_identity unless for_update
    authentication? ? validate_authentication : validate_content

    raise Ibsoft::MetaTemplates::TemplatePayload::ValidationError, errors if errors.present?
  end

  private

  attr_reader :attributes, :for_update, :errors

  def validate_common
    add_error(:category) unless payload_class::CATEGORIES.include?(category)
    add_error(:model) unless payload_class::MODELS.include?(model)
    add_error(:parameter_format) unless payload_class::PARAMETER_FORMATS.include?(parameter_format)
    add_error(:model) unless template_format_class.compatible?(model, category)
  end

  def validate_identity
    name = attributes['name'].to_s.strip
    valid_name = name.present? && name.length <= 512 && name.match?(payload_class::NAME_PATTERN)
    add_error(:name) unless valid_name
    add_error(:language) if attributes['language'].blank?
  end

  def validate_authentication
    expiration = authentication['code_expiration_minutes'].to_i
    add_error(:expiration) unless expiration.between?(1, 90)
  end

  def validate_content
    validate_body
    add_error(:footer) if footer['text'].to_s.length > 60
    add_error(:header) unless allowed_header_formats.include?(header_format)
    validate_header
    validate_variables(header['text'].to_s, header['examples'], :header) if header_format == 'TEXT'
    validate_variables(body['text'].to_s, body['examples'], :body)
    validate_actions
  end

  def validate_body
    text = body['text'].to_s.strip
    add_error(:body) if text.blank? || text.length > 1024
  end

  def validate_header
    return unless allowed_header_formats.include?(header_format)

    validate_text_header if header_format == 'TEXT'
    validate_media_header if %w[IMAGE VIDEO DOCUMENT].include?(header_format)
  end

  def validate_text_header
    text = header['text'].to_s.strip
    add_error(:header) if text.blank? || text.length > 60
    add_error(:header) if variable_names(text).size > 1
  end

  def validate_media_header
    add_error(:media) if header['media_handle'].blank?
  end

  def validate_variables(text, examples, field)
    named = text.scan(payload_class::NAMED_VARIABLE_PATTERN).flatten
    positional = text.scan(payload_class::POSITIONAL_VARIABLE_PATTERN).flatten
    expected, unexpected = expected_and_unexpected_variables(named, positional)

    add_error(field) if named.present? && positional.present?
    add_error(field) if unexpected.present? || expected.uniq.size != expected.size
    validate_variable_sequence(expected, field)
    validate_variable_examples(expected, examples, field)
  end

  def expected_and_unexpected_variables(named, positional)
    return [named, positional] if parameter_format == 'named'

    [positional, named]
  end

  def validate_variable_sequence(variables, field)
    return unless parameter_format == 'positional' && variables.present?

    expected = (1..variables.size).map(&:to_s)
    add_error(field) unless variables == expected
  end

  def validate_variable_examples(variables, examples, field)
    missing = variables.any? { |key| examples.to_h[key].to_s.strip.blank? }
    add_error("#{field}_examples".to_sym) if missing
  end

  def validate_buttons
    buttons = Array(attributes['buttons'])
    add_error(:buttons) if buttons.size > 10
    buttons.each { |button| validate_button(button) }
  end

  def validate_actions
    if template_definition[:generic_buttons]
      validate_buttons
    elsif Array(attributes['buttons']).present?
      add_error(:buttons)
    end

    validate_fixed_button if template_definition[:fixed_button_text_editable]
  end

  def validate_fixed_button
    text = special['button_text'].to_s.strip
    add_error(:special_action) if text.blank? || text.length > 25
  end

  def validate_button(button)
    type = button['type'].to_s.upcase
    text = button['text'].to_s.strip
    add_error(:buttons) unless payload_class::BUTTON_TYPES.include?(type)
    add_error(:buttons) if text.blank? || text.length > 25
    validate_button_destination(button, type)
  end

  def validate_button_destination(button, type)
    destination = {
      'URL' => button['url'],
      'PHONE_NUMBER' => button['phone_number']
    }[type]
    add_error(:buttons) if %w[URL PHONE_NUMBER].include?(type) && destination.to_s.strip.blank?
  end

  def variable_names(text)
    pattern = parameter_format == 'named' ? payload_class::NAMED_VARIABLE_PATTERN : payload_class::POSITIONAL_VARIABLE_PATTERN
    text.scan(pattern).flatten
  end

  def payload_class
    Ibsoft::MetaTemplates::TemplatePayload
  end

  def template_format_class
    Ibsoft::MetaTemplates::TemplateFormat
  end

  def category
    attributes['category'].to_s.upcase
  end

  def model
    attributes['model'].presence || (category == 'AUTHENTICATION' ? 'authentication' : 'standard')
  end

  def authentication?
    model == 'authentication'
  end

  def template_definition
    @template_definition ||= template_format_class.find(model) || {}
  end

  def allowed_header_formats
    template_definition.fetch(:header_formats, [])
  end

  def parameter_format
    attributes['parameter_format'].presence || 'positional'
  end

  def header
    attributes['header'].to_h.deep_stringify_keys
  end

  def header_format
    header['format'].presence&.upcase || 'NONE'
  end

  def body
    attributes['body'].to_h.deep_stringify_keys
  end

  def footer
    attributes['footer'].to_h.deep_stringify_keys
  end

  def authentication
    attributes['authentication'].to_h.deep_stringify_keys
  end

  def special
    attributes['special'].to_h.deep_stringify_keys
  end

  def add_error(field)
    message = I18n.t(
      "ibsoft_meta_templates.validation.#{field}",
      default: I18n.t('ibsoft_meta_templates.validation.invalid')
    )
    errors << { field: field.to_s, message: message }
  end
end
