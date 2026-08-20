/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class BusinessCalendarAPI extends ApiClient {
  constructor() {
    super('ibsoft/business_calendar', { accountScoped: true });
  }

  getCalendars() {
    return axios.get(`${this.url}/calendars`);
  }

  getCalendar(calendarId) {
    return axios.get(`${this.url}/calendars/${calendarId}`);
  }

  createCalendar(payload) {
    return axios.post(`${this.url}/calendars`, payload);
  }

  updateCalendar(calendarId, payload) {
    return axios.patch(`${this.url}/calendars/${calendarId}`, payload);
  }

  deleteCalendar(calendarId) {
    return axios.delete(`${this.url}/calendars/${calendarId}`);
  }

  updateCalendarTeamLinks(calendarId, teamIds) {
    return axios.patch(`${this.url}/calendars/${calendarId}/team_links`, {
      team_ids: teamIds,
    });
  }

  createHoliday(calendarId, payload) {
    return axios.post(`${this.url}/calendars/${calendarId}/holidays`, payload);
  }

  updateHoliday(calendarId, holidayId, payload) {
    return axios.patch(
      `${this.url}/calendars/${calendarId}/holidays/${holidayId}`,
      payload
    );
  }

  deleteHoliday(calendarId, holidayId) {
    return axios.delete(
      `${this.url}/calendars/${calendarId}/holidays/${holidayId}`
    );
  }

  previewImport(calendarId, payload) {
    return axios.post(
      `${this.url}/calendars/${calendarId}/holiday_import/preview`,
      payload
    );
  }

  importHolidays(calendarId, payload) {
    return axios.post(
      `${this.url}/calendars/${calendarId}/holiday_import`,
      payload
    );
  }

  getTeamLink(teamId) {
    return axios.get(`${this.url}/team_links/${teamId}`);
  }

  updateTeamLink(teamId, businessCalendarId) {
    return axios.patch(`${this.url}/team_links/${teamId}`, {
      business_calendar_id: businessCalendarId,
    });
  }

  deleteTeamLink(teamId) {
    return axios.delete(`${this.url}/team_links/${teamId}`);
  }
}

export default new BusinessCalendarAPI();
