require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::ActionServiceExtension do
  let(:account) { create(:account) }
  let(:source_team) { create(:team, account: account) }
  let(:target_team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, team: source_team) }
  let(:action_service) { ActionService.new(conversation) }

  after do
    Current.reset
  end

  it 'is prepended without changing the native ActionService file' do
    aggregate_failures do
      expect(ActionService.ancestors).to include(described_class)
      expect(Conversation.ancestors).to include(Ibsoft::ConversationDistribution::TeamAssignmentSourceMarker)
    end
  end

  it 'marks a manual team change' do
    action_service.assign_team([target_team.id])

    expect(conversation.reload).to have_attributes(team: target_team)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'persists the team and source marker in one conversation update' do
    conversation_updates = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      conversation_updates << payload[:sql] if payload[:sql].start_with?('UPDATE "conversations"')
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      action_service.assign_team([target_team.id])
    end

    expect(conversation_updates.one?).to be(true)
  end

  it 'preserves the native team changed event' do
    allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

    action_service.assign_team([target_team.id])

    expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
      Events::Types::TEAM_CHANGED,
      kind_of(ActiveSupport::TimeWithZone),
      hash_including(
        conversation: conversation,
        changed_attributes: hash_including('team_id' => [source_team.id, target_team.id])
      )
    ).once
  end

  it 'marks an automation team change as a system transfer' do
    Current.executed_by = create(:automation_rule, account: account)

    action_service.assign_team([target_team.id])

    expect(conversation.reload.additional_attributes['ibsoft_distribution_source']).to eq('system_team_transfer')
  end

  it 'does not replace the marker when the team remains unchanged' do
    marked_at = 1.hour.ago.iso8601
    conversation.update!(
      additional_attributes: {
        'ibsoft_distribution_source' => 'manual_team_transfer',
        'ibsoft_distribution_source_marked_at' => marked_at
      }
    )

    action_service.assign_team([source_team.id])

    expect(conversation.reload.additional_attributes['ibsoft_distribution_source_marked_at']).to eq(marked_at)
  end

  it 'does not mark a team from another account' do
    foreign_team = create(:team)

    action_service.assign_team([foreign_team.id])

    expect(conversation.reload).to have_attributes(team: source_team)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to be_nil
  end

  it 'does not retain source marking context after the assignment' do
    action_service.assign_team([target_team.id])

    expect(Ibsoft::ConversationDistribution::TeamAssignmentContext.source_marking_enabled).to be_nil
  end

  it 'rolls the team change back when source marking fails' do
    source_marker = instance_double(Ibsoft::ConversationDistribution::SourceMarker)
    allow(Ibsoft::ConversationDistribution::SourceMarker).to receive(:new).and_return(source_marker)
    allow(source_marker).to receive(:assign).and_raise(ActiveRecord::RecordInvalid)

    expect { action_service.assign_team([target_team.id]) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(conversation.reload.team).to eq(source_team)
  end
end
