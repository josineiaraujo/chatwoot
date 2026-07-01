require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::SourceMarker do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'marks a conversation with an explicit distribution source' do
    described_class.new(
      conversation: conversation,
      source: 'system_team_transfer',
      reason: 'automation'
    ).perform

    conversation.reload
    expect(conversation.additional_attributes).to include(
      'ibsoft_distribution_source' => 'system_team_transfer',
      'ibsoft_distribution_source_reason' => 'automation'
    )
    expect(conversation.additional_attributes['ibsoft_distribution_source_marked_at']).to be_present
  end

  it 'uses manual team transfer when there is no system actor' do
    described_class.new(conversation: conversation).perform

    expect(conversation.reload.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'uses system team transfer when an automation rule is executing' do
    Current.executed_by = create(:automation_rule, account: account)

    described_class.new(conversation: conversation).perform

    expect(conversation.reload.additional_attributes['ibsoft_distribution_source']).to eq('system_team_transfer')
  ensure
    Current.reset
  end
end
