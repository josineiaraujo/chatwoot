require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdate, type: :model do
  it 'requires at least one requested status' do
    update = build(
      :ibsoft_external_message_order_update,
      order_status: nil,
      payment_status: nil
    )

    expect(update).not_to be_valid
  end

  it 'rejects relations from another tenant' do
    update = build(
      :ibsoft_external_message_order_update,
      endpoint: create(:ibsoft_external_message_endpoint)
    )

    expect(update).not_to be_valid
  end
end
