class Ibsoft::MessageBroadcast::TemplateContentRenderer
  VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

  def initialize(channel:, template_params:)
    @channel = channel
    @template_params = template_params
  end

  def call
    body_template.to_s.gsub(VARIABLE_PATTERN) do
      key = ::Regexp.last_match(1).to_s
      body_params[key].presence || "{{#{key}}}"
    end
  end

  private

  attr_reader :channel, :template_params

  def body_template
    template_components.find { |component| component['type'].to_s.casecmp('BODY').zero? }&.dig('text')
  end

  def template_components
    template = channel.message_templates.to_a.find do |candidate|
      candidate['name'] == template_params['name'] &&
        candidate['language'].to_s.casecmp(template_params['language'].to_s).zero?
    end

    Array(template&.dig('components'))
  end

  def body_params
    template_params.dig('processed_params', 'body') || {}
  end
end
