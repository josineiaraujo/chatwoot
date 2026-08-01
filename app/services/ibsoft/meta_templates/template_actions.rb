class Ibsoft::MetaTemplates::TemplateActions
  def initialize(attributes, definition)
    @attributes = attributes
    @definition = definition
  end

  def components
    actions = []
    actions << generic_buttons_component if definition[:generic_buttons] && buttons.present?
    actions << fixed_button_component if definition[:fixed_button_type].present?
    actions << { 'type' => definition[:component_type] } if definition[:component_type].present?
    actions
  end

  private

  attr_reader :attributes, :definition

  def buttons
    Array(attributes['buttons'])
  end

  def special
    attributes['special'].to_h.deep_stringify_keys
  end

  def generic_buttons_component
    {
      'type' => 'BUTTONS',
      'buttons' => buttons.map do |button|
        {
          'type' => button['type'].to_s.upcase,
          'text' => button['text'].to_s.strip,
          'url' => button['url'].presence,
          'phone_number' => button['phone_number'].presence,
          'example' => button['example'].present? ? [button['example'].to_s] : nil
        }.compact
      end
    }
  end

  def fixed_button_component
    {
      'type' => 'BUTTONS',
      'buttons' => [
        {
          'type' => definition[:fixed_button_type],
          'text' => fixed_button_text
        }
      ]
    }
  end

  def fixed_button_text
    definition[:fixed_button_text].presence || special['button_text'].to_s.strip
  end
end
