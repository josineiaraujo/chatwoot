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

  it 'accepts a complete template delivery snapshot' do
    update = create(:ibsoft_external_message_order_update)
    update.assign_attributes(
      delivery_method: 'template',
      template_name: 'atualizacao_fatura',
      template_language: 'pt_BR',
      template_components: []
    )

    expect(update).to be_valid
  end

  it 'rejects an incomplete template delivery snapshot' do
    update = build(
      :ibsoft_external_message_order_update,
      delivery_method: 'template',
      template_name: nil,
      template_language: 'pt_BR'
    )

    expect(update).not_to be_valid
    expect(update.errors[:template_name]).to be_present
  end

  it 'rejects template metadata on an interactive update' do
    update = build(
      :ibsoft_external_message_order_update,
      delivery_method: 'interactive',
      template_name: 'atualizacao_fatura',
      template_language: 'pt_BR'
    )

    expect(update).not_to be_valid
  end
end
