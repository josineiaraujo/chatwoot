require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::RequestIdentityKey do
  it 'returns a unique internal key for every submission' do
    first = described_class.new.call
    second = described_class.new.call

    expect(first).to start_with('request-')
    expect(second).not_to eq(first)
  end
end
