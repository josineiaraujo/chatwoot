require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Ibsoft::BusinessCalendar::Calendars', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account) }
  let(:manager) { create(:user, account: account) }
  let(:team) { create(:team, account: account) }
  let(:admin_headers) { { api_access_token: admin.access_token.token } }
  let(:agent_headers) { { api_access_token: agent.access_token.token } }
  let(:manager_headers) { { api_access_token: manager.access_token.token } }
  let(:base_url) { "/api/v1/accounts/#{account.id}/ibsoft/business_calendar" }

  def grant_settings_permission(user)
    role = create(
      :ibsoft_access_control_role,
      account: account,
      permissions: [Ibsoft::ChathubSettings::Permission::PERMISSION]
    )
    create(:ibsoft_access_control_role_assignment, account: account, role: role, user: user)
  end

  it 'allows an administrator to manage calendars and manual holidays' do
    post "#{base_url}/calendars",
         params: { name: 'Feriados da operacao' },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    calendar_id = response.parsed_body.fetch('id')

    post "#{base_url}/calendars/#{calendar_id}/holidays",
         params: { holiday_date: '2026-12-25', name: 'Natal' },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    holiday_id = response.parsed_body.fetch('id')
    expect(response.parsed_body).to include(
      'holiday_date' => '2026-12-25',
      'name' => 'Natal',
      'source' => 'manual'
    )

    patch "#{base_url}/calendars/#{calendar_id}/holidays/#{holiday_id}",
          params: { holiday_date: '2026-12-25', name: 'Natal atualizado' },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['name']).to eq('Natal atualizado')

    get "#{base_url}/calendars/#{calendar_id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('holidays').pluck('id')).to contain_exactly(holiday_id)
  end

  it 'allows a user with the private settings permission to list calendars' do
    grant_settings_permission(manager)
    create(:ibsoft_business_calendar, account: account, name: 'Calendario autorizado')

    get "#{base_url}/calendars", headers: manager_headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('calendars').pluck('name')).to include('Calendario autorizado')
  end

  it 'blocks regular agents from managing calendars' do
    get "#{base_url}/calendars", headers: agent_headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not expose a calendar from another account' do
    other_account = create(:account)
    foreign_calendar = create(:ibsoft_business_calendar, account: other_account)

    get "#{base_url}/calendars/#{foreign_calendar.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'previews and imports only national and selected state holidays without a real HTTP request' do
    calendar = create(:ibsoft_business_calendar, account: account)
    client = instance_double(Ibsoft::BusinessCalendar::InvertextoClient)
    allow(Ibsoft::BusinessCalendar::InvertextoClient).to receive(:new).and_return(client)
    allow(client).to receive(:holidays).with(year: 2026, state_code: 'BA').and_return(
      [
        { date: '2026-01-01', name: 'Confraternizacao', type: 'feriado', level: 'nacional' },
        { date: '2026-07-02', name: 'Independencia da Bahia', type: 'feriado', level: 'estadual' },
        { date: '2026-06-24', name: 'Sao Joao municipal', type: 'feriado', level: 'municipal' }
      ]
    )

    post "#{base_url}/calendars/#{calendar.id}/holiday_import/preview",
         params: { year: 2026, state_code: 'BA' },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('holidays').pluck('name')).to contain_exactly(
      'Confraternizacao',
      'Independencia da Bahia'
    )
    expect(calendar.holidays).to be_empty

    post "#{base_url}/calendars/#{calendar.id}/holiday_import",
         params: { year: 2026, state_code: 'BA', holiday_dates: ['2026-07-02'] },
         headers: admin_headers,
         as: :json

    expect(response).to have_http_status(:success)
    expect(calendar.reload.holidays.pluck(:name)).to eq(['Independencia da Bahia'])
  end

  it 'links and removes a calendar from a department' do
    calendar = create(:ibsoft_business_calendar, account: account)

    patch "#{base_url}/team_links/#{team.id}",
          params: { business_calendar_id: calendar.id },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'team_id' => team.id,
      'business_calendar_id' => calendar.id
    )

    delete "#{base_url}/team_links/#{team.id}", headers: admin_headers, as: :json

    expect(response).to have_http_status(:no_content)
    expect(Ibsoft::BusinessCalendar::TeamLink.find_by(account: account, team: team)).to be_nil
  end

  it 'rejects linking a department to a calendar from another account' do
    other_account = create(:account)
    foreign_calendar = create(:ibsoft_business_calendar, account: other_account)

    patch "#{base_url}/team_links/#{team.id}",
          params: { business_calendar_id: foreign_calendar.id },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:not_found)
    expect(Ibsoft::BusinessCalendar::TeamLink.find_by(account: account, team: team)).to be_nil
  end

  it 'replaces all department links for a calendar in one account-scoped operation' do
    calendar = create(:ibsoft_business_calendar, account: account)
    other_calendar = create(:ibsoft_business_calendar, account: account)
    selected_team = create(:team, account: account)
    moved_team = create(:team, account: account)
    removed_team = create(:team, account: account)
    create(:ibsoft_business_calendar_team_link, account: account, business_calendar: other_calendar, team: moved_team)
    create(:ibsoft_business_calendar_team_link, account: account, business_calendar: calendar, team: removed_team)

    patch "#{base_url}/calendars/#{calendar.id}/team_links",
          params: { team_ids: [selected_team.id, moved_team.id] },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('team_ids')).to contain_exactly(selected_team.id, moved_team.id)
    expect(calendar.reload.team_ids).to contain_exactly(selected_team.id, moved_team.id)
    expect(other_calendar.reload.team_ids).to be_empty
    expect(Ibsoft::BusinessCalendar::TeamLink.find_by(account: account, team: removed_team)).to be_nil
  end

  it 'does not change calendar links when any department belongs to another account' do
    calendar = create(:ibsoft_business_calendar, account: account)
    linked_team = create(:team, account: account)
    foreign_team = create(:team)
    create(:ibsoft_business_calendar_team_link, account: account, business_calendar: calendar, team: linked_team)

    patch "#{base_url}/calendars/#{calendar.id}/team_links",
          params: { team_ids: [foreign_team.id] },
          headers: admin_headers,
          as: :json

    expect(response).to have_http_status(:not_found)
    expect(calendar.reload.team_ids).to contain_exactly(linked_team.id)
  end
end
