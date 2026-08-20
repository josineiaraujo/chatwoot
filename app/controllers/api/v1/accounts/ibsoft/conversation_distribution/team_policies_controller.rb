class Api::V1::Accounts::Ibsoft::ConversationDistribution::TeamPoliciesController <
  Api::V1::Accounts::Ibsoft::ConversationDistribution::BaseController
  before_action :fetch_team, only: [:show, :update]

  def show
    render json: response_payload
  end

  def update
    ApplicationRecord.transaction do
      policy.override_channel_policy = boolean_param(:override_channel_policy) if params.key?(:override_channel_policy)
      assign_distribution_policy(policy)
      policy.save!
      update_business_calendar_link if params.key?(:business_calendar_id)
    end

    render json: response_payload
  end

  private

  def policy
    @policy ||= Ibsoft::ConversationDistribution::TeamPolicy.find_or_initialize_by(
      account: Current.account,
      team: @team,
      inbox: optional_policy_inbox
    )
  end

  def response_payload
    policy.payload.merge(business_calendar_payload)
  end

  def business_calendar_payload
    link = Ibsoft::BusinessCalendar::TeamLink.find_by(account: Current.account, team: @team)
    return { business_calendar_id: nil, business_calendar_name: nil } if link.blank?

    {
      business_calendar_id: link.business_calendar_id,
      business_calendar_name: link.business_calendar.name
    }
  end

  def update_business_calendar_link
    Ibsoft::BusinessCalendar::TeamLinkUpdater.new(
      account: Current.account,
      team: @team,
      business_calendar_id: params[:business_calendar_id]
    ).perform
  end
end
