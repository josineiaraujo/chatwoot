# frozen_string_literal: true

class Api::V1::Accounts::Ibsoft::InstagramInbound::InboxPoliciesController <
  Api::V1::Accounts::Ibsoft::InstagramInbound::BaseController
  def show
    render json: policy.as_api_json
  end

  def update
    policy.assign_attributes(policy_params)

    if policy.save
      render json: policy.as_api_json
    else
      render json: { error: I18n.t('ibsoft_instagram_inbound.errors.invalid_configuration') },
             status: :unprocessable_content
    end
  end

  private

  def policy
    @policy ||= Ibsoft::InstagramInbound::Policy.find_or_initialize_by(
      account: Current.account,
      inbox: @inbox
    )
  end

  def policy_params
    params.permit(
      :create_from_story_interactions,
      :create_from_shared_reels_and_stories,
      :create_from_shared_posts
    )
  end
end
