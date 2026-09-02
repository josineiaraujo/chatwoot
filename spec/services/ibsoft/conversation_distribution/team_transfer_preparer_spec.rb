require 'rails_helper'

RSpec.describe Ibsoft::ConversationDistribution::TeamTransferPreparer do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:source_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:target_team) { create(:team, account: account, allow_auto_assign: false) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, team: source_team, assignee: agent)
  end

  before do
    create(:team_member, team: source_team, user: agent)
    create(:team_member, team: target_team, user: agent)
    create(:ibsoft_distribution_channel_policy, account: account, inbox: inbox, enabled: true)

    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive_messages(
      job_enabled?: true,
      real_assignment_enabled?: true
    )
  end

  it 'clears the current assignee before an eligible manual team transfer' do
    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to be_nil
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'clears the complete AI owner before an eligible manual team transfer' do
    agent_bot = create(:agent_bot, account: account)
    owner_attribute = conversation.respond_to?(:ai_assignee=) ? :ai_assignee : :assignee_agent_bot
    conversation.update!({ :assignee => nil, owner_attribute => agent_bot })

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee_agent_bot).to be_nil
    expect(conversation.ai_assignee).to be_nil if conversation.respond_to?(:ai_assignee)
    expect(conversation.ai_assignee_type).to be_nil if conversation.has_attribute?(:ai_assignee_type)
  end

  it 'preserves the assignee when the effective policy is disabled' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(enabled: false)

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to eq(agent)
  end

  it 'preserves the assignee while real assignment is in safe mode' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:real_assignment_enabled?).and_return(false)

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to eq(agent)
  end

  it 'preserves the assignee while the automatic job is disabled' do
    allow(Ibsoft::ConversationDistribution::ExecutionConfig).to receive(:job_enabled?).and_return(false)

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to eq(agent)
  end

  it 'preserves the assignee when the source is excluded by the policy' do
    Ibsoft::ConversationDistribution::ChannelPolicy.find_by!(account: account, inbox: inbox)
                                                   .distribution_policy
                                                   .update!(config: { eligible_sources: ['bot_handoff'] })

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to eq(agent)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to eq('manual_team_transfer')
  end

  it 'preserves the assignee when the same team is selected again' do
    described_class.new(conversation: conversation, team: source_team).prepare

    expect(conversation.assignee).to eq(agent)
    expect(conversation.additional_attributes['ibsoft_distribution_source']).to be_nil
  end

  it 'preserves native assignment behavior while target team auto assignment is enabled' do
    target_team.update!(allow_auto_assign: true)

    described_class.new(conversation: conversation, team: target_team).prepare

    expect(conversation.assignee).to eq(agent)
  end
end
