/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class InstagramInboundAPI extends ApiClient {
  constructor() {
    super('ibsoft/instagram_inbound', { accountScoped: true });
  }

  getInboxPolicy(inboxId) {
    return axios.get(`${this.url}/inbox_policies/${inboxId}`);
  }

  updateInboxPolicy(inboxId, payload) {
    return axios.patch(`${this.url}/inbox_policies/${inboxId}`, payload);
  }
}

export default new InstagramInboundAPI();
