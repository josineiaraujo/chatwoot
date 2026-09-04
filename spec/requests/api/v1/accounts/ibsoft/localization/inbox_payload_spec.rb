require 'rails_helper'

RSpec.describe 'Ibsoft localization in inbox payload', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account) }

  it 'returns working-hour breaks in the native inbox payload' do
    create(
      :ibsoft_working_hour_break,
      inbox: inbox,
      day_of_week: 2,
      start_hour: 12,
      start_minutes: 15,
      end_hour: 13,
      end_minutes: 45
    )

    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('ibsoft_working_hour_breaks')).to contain_exactly(
      {
        'day_of_week' => 2,
        'start_hour' => 12,
        'start_minutes' => 15,
        'end_hour' => 13,
        'end_minutes' => 45
      }
    )
  end
end
