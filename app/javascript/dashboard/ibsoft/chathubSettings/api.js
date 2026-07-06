/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class ChathubSettingsAPI extends ApiClient {
  constructor() {
    super('ibsoft/chathub_settings', { accountScoped: true });
  }

  getSettings() {
    return axios.get(`${this.url}/setting`);
  }

  updateSettings(payload) {
    return axios.patch(`${this.url}/setting`, payload);
  }
}

export default new ChathubSettingsAPI();
