/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class ConversationDistributionAPI extends ApiClient {
  constructor() {
    super('ibsoft/conversation_distribution', { accountScoped: true });
  }

  getInboxPolicy(inboxId) {
    return axios.get(`${this.url}/inbox_policies/${inboxId}`);
  }

  updateInboxPolicy(inboxId, payload) {
    return axios.patch(`${this.url}/inbox_policies/${inboxId}`, payload);
  }

  getTeamPolicy(teamId, policyInboxId = null) {
    return axios.get(`${this.url}/team_policies/${teamId}`, {
      params: { policy_inbox_id: policyInboxId },
    });
  }

  updateTeamPolicy(teamId, payload) {
    return axios.patch(`${this.url}/team_policies/${teamId}`, payload);
  }

  copyTeamPolicy(payload) {
    return axios.post(`${this.url}/team_policies/copy`, payload);
  }

  getEffectivePolicy({ inboxId, teamId }) {
    return axios.get(`${this.url}/effective_policy`, {
      params: { inbox_id: inboxId, team_id: teamId },
    });
  }
}

export default new ConversationDistributionAPI();
