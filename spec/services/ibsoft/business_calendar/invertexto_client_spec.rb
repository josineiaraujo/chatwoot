require 'rails_helper'

RSpec.describe Ibsoft::BusinessCalendar::InvertextoClient do
  describe '#holidays' do
    it 'requires the server-side environment token' do
      client = described_class.new(token: nil)

      expect { client.holidays(year: 2026) }
        .to raise_error(described_class::RequestError, 'missing_token')
    end

    it 'requests a state calendar using bearer authentication' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: [{ 'name' => 'Natal' }])
      allow(HTTParty).to receive(:get).and_return(response)

      result = described_class.new(token: 'secret-token').holidays(year: 2026, state_code: 'ba')

      expect(result).to eq([{ 'name' => 'Natal' }])
      expect(HTTParty).to have_received(:get).with(
        'https://api.invertexto.com/v1/holidays/2026',
        headers: { 'Authorization' => 'Bearer secret-token' },
        query: { state: 'BA' },
        timeout: described_class::REQUEST_TIMEOUT
      )
    end

    it 'reads the integration token from the server environment by default' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: [])
      allow(HTTParty).to receive(:get).and_return(response)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch)
        .with('IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN', nil)
        .and_return('server-environment-token')

      described_class.new.holidays(year: 2026)

      expect(HTTParty).to have_received(:get).with(
        'https://api.invertexto.com/v1/holidays/2026',
        hash_including(headers: { 'Authorization' => 'Bearer server-environment-token' })
      )
    end

    it 'does not send a state filter for a national import' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: [])
      allow(HTTParty).to receive(:get).and_return(response)

      described_class.new(token: 'secret-token').holidays(year: 2026)

      expect(HTTParty).to have_received(:get).with(
        'https://api.invertexto.com/v1/holidays/2026',
        hash_including(query: {})
      )
    end

    it 'converts unsuccessful responses into a bounded integration error' do
      response = instance_double(HTTParty::Response, success?: false, code: 429)
      allow(HTTParty).to receive(:get).and_return(response)

      expect { described_class.new(token: 'secret-token').holidays(year: 2026) }
        .to raise_error(described_class::RequestError, 'http_429')
    end
  end
end
