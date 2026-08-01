class Ibsoft::MetaTemplates::TemplatePayload
  CATEGORIES = %w[MARKETING UTILITY AUTHENTICATION].freeze
  MODELS = Ibsoft::MetaTemplates::TemplateFormat.models.freeze
  PARAMETER_FORMATS = %w[named positional].freeze
  HEADER_FORMATS = %w[NONE TEXT IMAGE VIDEO DOCUMENT].freeze
  BUTTON_TYPES = %w[QUICK_REPLY URL PHONE_NUMBER].freeze
  NAME_PATTERN = /\A[a-z0-9_]+\z/
  NAMED_VARIABLE_PATTERN = /\{\{\s*([a-z][a-z0-9_]*)\s*\}\}/
  POSITIONAL_VARIABLE_PATTERN = /\{\{\s*(\d+)\s*\}\}/

  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.join(', '))
    end
  end

  def initialize(attributes)
    @attributes = attributes.to_h.deep_stringify_keys
  end

  def create_payload
    validate!(for_update: false)
    base_payload.merge(
      'name' => attributes['name'].to_s.strip,
      'language' => attributes['language'].to_s
    )
  end

  def update_payload
    validate!(for_update: true)
    base_payload
  end

  private

  attr_reader :attributes

  def validate!(for_update:)
    Ibsoft::MetaTemplates::TemplateValidator.new(
      attributes,
      for_update: for_update
    ).validate!
  end

  def base_payload
    payload = {
      'category' => category,
      'parameter_format' => parameter_format,
      'components' => template_components
    }
    payload['display_format'] = template_definition[:display_format] if template_definition[:display_format].present?
    payload['sub_category'] = template_definition[:sub_category] if template_definition[:sub_category].present?
    payload
  end

  def template_components
    return authentication_components if authentication?

    components = content_components
    components.concat(
      Ibsoft::MetaTemplates::TemplateActions.new(
        attributes,
        template_definition
      ).components
    )
    components
  end

  def authentication_components
    [
      {
        'type' => 'BODY',
        'add_security_recommendation' => authentication['add_security_recommendation'] != false
      },
      {
        'type' => 'FOOTER',
        'code_expiration_minutes' => authentication['code_expiration_minutes'].to_i
      },
      {
        'type' => 'BUTTONS',
        'buttons' => [
          {
            'type' => 'OTP',
            'otp_type' => authentication['otp_type'].presence || 'COPY_CODE'
          }
        ]
      }
    ]
  end

  def content_components
    components = []
    if template_definition[:header_formats].exclude?('NONE') || template_definition[:header_formats].size > 1
      header_component = build_header_component
      components << header_component if header_component.present?
    end
    components << text_component('BODY', body['text'], body['examples'])
    components << { 'type' => 'FOOTER', 'text' => footer['text'].to_s.strip } if footer['text'].present?
    components
  end

  def build_header_component
    return if header_format == 'NONE'

    if header_format == 'TEXT'
      text_component('HEADER', header['text'], header['examples']).merge('format' => 'TEXT')
    else
      {
        'type' => 'HEADER',
        'format' => header_format,
        'example' => { 'header_handle' => [header['media_handle'].to_s] }
      }
    end
  end

  def text_component(type, text, examples)
    component = {
      'type' => type,
      'text' => text.to_s.strip
    }
    example = build_text_example(type, text.to_s, examples.to_h)
    component['example'] = example if example.present?
    component
  end

  def build_text_example(type, text, examples)
    keys = variable_names(text)
    return if keys.blank?

    prefix = type.downcase
    if parameter_format == 'named'
      {
        "#{prefix}_text_named_params" => keys.map do |key|
          { 'param_name' => key, 'example' => examples[key].to_s }
        end
      }
    elsif type == 'BODY'
      { 'body_text' => [keys.map { |key| examples[key].to_s }] }
    else
      { "#{prefix}_text" => keys.map { |key| examples[key].to_s } }
    end
  end

  def variable_names(text)
    pattern = parameter_format == 'named' ? NAMED_VARIABLE_PATTERN : POSITIONAL_VARIABLE_PATTERN
    text.scan(pattern).flatten
  end

  def category
    attributes['category'].to_s.upcase
  end

  def model
    attributes['model'].presence || (category == 'AUTHENTICATION' ? 'authentication' : 'standard')
  end

  def template_definition
    @template_definition ||= Ibsoft::MetaTemplates::TemplateFormat.find(model) || {}
  end

  def authentication?
    model == 'authentication'
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
end
