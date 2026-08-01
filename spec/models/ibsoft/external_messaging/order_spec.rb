require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::Order, type: :model do
  it 'scopes the external reference by account and inbox' do
    order = create(:ibsoft_external_message_order)

    duplicate = build(
      :ibsoft_external_message_order,
      account: order.account,
      inbox: order.inbox,
      reference_id: order.reference_id
    )

    expect(duplicate).not_to be_valid
  end

  it 'is ready only after the opening delivery is accepted with a Meta ID' do
    order = create(:ibsoft_external_message_order)
    expect(order).to be_ready_for_updates

    order.opening_delivery.update!(status: 'queued', meta_message_id: nil)
    expect(order).not_to be_ready_for_updates
  end
end
