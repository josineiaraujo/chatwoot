class Ibsoft::MetaTemplates::TemplateFormat
  DEFINITIONS = {
    'standard' => {
      categories: %w[MARKETING UTILITY],
      header_formats: %w[NONE TEXT IMAGE VIDEO DOCUMENT],
      generic_buttons: true
    },
    'catalog' => {
      categories: %w[MARKETING],
      header_formats: %w[NONE],
      fixed_button_type: 'CATALOG',
      fixed_button_text_editable: true
    },
    'order_details' => {
      categories: %w[MARKETING UTILITY],
      header_formats: %w[NONE IMAGE DOCUMENT],
      display_format: 'ORDER_DETAILS',
      fixed_button_type: 'ORDER_DETAILS',
      fixed_button_text: 'Copy Pix code'
    },
    'order_status' => {
      categories: %w[UTILITY],
      header_formats: %w[NONE],
      sub_category: 'ORDER_STATUS'
    },
    'call_permission_request' => {
      categories: %w[MARKETING UTILITY],
      header_formats: %w[NONE TEXT IMAGE VIDEO DOCUMENT],
      component_type: 'CALL_PERMISSION_REQUEST'
    },
    'authentication' => {
      categories: %w[AUTHENTICATION],
      header_formats: %w[NONE]
    }
  }.freeze

  class << self
    def all
      DEFINITIONS
    end

    def models
      DEFINITIONS.keys
    end

    def find(model)
      DEFINITIONS[model.to_s]
    end

    def compatible?(model, category)
      find(model)&.fetch(:categories, [])&.include?(category.to_s.upcase) || false
    end
  end
end
