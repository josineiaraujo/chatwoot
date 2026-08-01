require 'rails_helper'
require 'yaml'

RSpec.describe I18n do
  def each_translation(value, path = [], &)
    case value
    when Hash
      value.each do |key, child|
        each_translation(child, path + [key], &)
      end
    when Array
      value.each_with_index do |child, index|
        each_translation(child, path + [index], &)
      end
    when String
      yield value, path.join('.')
    end
  end

  it 'loads and interpolates every private backend translation' do
    files = Dir[Rails.root.join('config/locales/{ibsoft_,zz_ibsoft_}*.yml')]
    errors = []

    files.each do |file|
      translations = YAML.safe_load_file(file, aliases: true)

      each_translation(translations) do |message, key|
        interpolation_keys = message.scan(/%\{([^}]+)\}/).flatten
        remaining_message = message.gsub(/%\{[^}]+\}/, '')

        if remaining_message.include?('%{')
          errors << "#{file}:#{key}: malformed interpolation"
          next
        end

        values = interpolation_keys.to_h { |name| [name.to_sym, 'value'] }
        described_class.interpolate(message, values)
      rescue StandardError => e
        errors << "#{file}:#{key}: #{e.message}"
      end
    rescue Psych::Exception => e
      errors << "#{file}: #{e.message}"
    end

    expect(files).not_to be_empty
    expect(errors).to be_empty, errors.join("\n")
  end
end
