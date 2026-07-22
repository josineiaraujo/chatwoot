# frozen_string_literal: true

class Ibsoft::MessageSignature::NativeFooterSanitizer
  DELIMITER = '--'

  def initialize(content:, native_signature:)
    @content = content.to_s
    @native_signature = native_signature.to_s
  end

  def call
    return content if content.blank? || native_signature.blank?

    signature_variants.each do |signature|
      suffix = "\n\n#{DELIMITER}\n\n#{signature}"
      return content.rstrip.delete_suffix(suffix).rstrip if content.rstrip.end_with?(suffix)
    end

    content
  end

  private

  attr_reader :content, :native_signature

  def signature_variants
    [native_signature.strip, plain_text_signature].compact_blank.uniq
  end

  def plain_text_signature
    native_signature
      .gsub(/!\[[^\]]*\]\([^)]*\)/, '')
      .gsub(/\[([^\]]+)\]\([^)]+\)/, '\\1')
      .gsub(/[`*_~]/, '')
      .lines.map(&:strip).compact_blank.join("\n")
      .presence
  end
end
