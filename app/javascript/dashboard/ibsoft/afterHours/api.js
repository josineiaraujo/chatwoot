/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class AfterHoursAPI extends ApiClient {
  constructor() {
    super('ibsoft/after_hours', { accountScoped: true });
  }

  getPolicies() {
    return axios.get(`${this.url}/policies`);
  }

  createPolicy(payload) {
    return axios.post(`${this.url}/policies`, payload);
  }

  updatePolicy(policyId, payload) {
    return axios.patch(`${this.url}/policies/${policyId}`, payload);
  }

  deletePolicy(policyId) {
    return axios.delete(`${this.url}/policies/${policyId}`);
  }
}

export default new AfterHoursAPI();
