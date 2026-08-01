require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::ValueCoercion do
  def invalid_request
    yield
    raise 'Expected Ibsoft::ExternalMessaging::InvalidRequest'
  rescue Ibsoft::ExternalMessaging::InvalidRequest => e
    e
  end

  describe '.money_to_minor' do
    it 'converts Brazilian and decimal monetary formats to minor units' do
      expect(described_class.money_to_minor('R$ 1.234,56', field: 'total')).to eq(123_456)
      expect(described_class.money_to_minor('64.9', field: 'total')).to eq(6490)
    end

    it 'rejects zero and ambiguous monetary values' do
      error = invalid_request do
        described_class.money_to_minor('0,00', field: 'total')
      end
      expect(error.code).to eq('money_invalid')

      expect do
        described_class.money_to_minor('1,234.56', field: 'total')
      end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest)
    end
  end

  describe '.https_url' do
    it 'accepts public HTTPS URLs and rejects credentials or insecure schemes' do
      expect(
        described_class.https_url('https://files.example.com/invoice.pdf', field: 'header.link')
      ).to eq('https://files.example.com/invoice.pdf')

      %w[http://files.example.com/invoice.pdf https://user:secret@files.example.com/invoice.pdf].each do |url|
        expect do
          described_class.https_url(url, field: 'header.link')
        end.to raise_error(Ibsoft::ExternalMessaging::InvalidRequest)
      end
    end
  end

  describe '.future_timestamp' do
    it 'normalizes ISO 8601 and Unix millisecond values' do
      future = 1.year.from_now.change(usec: 0)

      expect(
        described_class.future_timestamp(future.iso8601, field: 'order.expiration_at')
      ).to eq(future.to_i.to_s)
      expect(
        described_class.future_timestamp((future.to_i * 1000).to_s, field: 'order.expiration_at')
      ).to eq(future.to_i.to_s)
    end
  end
end
