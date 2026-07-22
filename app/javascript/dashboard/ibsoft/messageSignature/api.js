/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class MessageSignatureAPI extends ApiClient {
  constructor() {
    super('ibsoft/message_signature', { accountScoped: true });
  }

  getSetting() {
    return axios.get(`${this.url}/setting`);
  }

  updateSetting(payload) {
    return axios.patch(`${this.url}/setting`, payload);
  }
}

export default new MessageSignatureAPI();
