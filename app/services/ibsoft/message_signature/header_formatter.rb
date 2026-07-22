# frozen_string_literal: true

class Ibsoft::MessageSignature::HeaderFormatter
  FALLBACK_MAX_CONTENT_LENGTH = 150_000

  def initialize(content:, agent_name:)
    @content = content.to_s
    @agent_name = agent_name.to_s.squish
  end

  def call
    return content if content.blank? || agent_name.blank?
    return content if already_signed?

    formatted_content = "#{header}\n\n#{content}"
    formatted_content.length <= max_content_length ? formatted_content : content
  end

  private

  attr_reader :content, :agent_name

  def header
    @header ||= "**#{escaped_agent_name}**"
  end

  def escaped_agent_name
    agent_name.gsub(/([\\`*_{}\[\]()#+\-.!~>])/) { |character| "\\#{character}" }
  end

  def already_signed?
    content == header || content.start_with?("#{header}\n")
  end

  def max_content_length
    length_validators = Message.validators_on(:content).select do |validator|
      validator.is_a?(ActiveModel::Validations::LengthValidator)
    end

    length_validators.filter_map { |validator| validator.options[:maximum] }.min || FALLBACK_MAX_CONTENT_LENGTH
  end
end
