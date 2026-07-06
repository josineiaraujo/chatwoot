/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class ChathubAnalyticsAPI extends ApiClient {
  constructor() {
    super('ibsoft/chathub_analytics', { accountScoped: true });
  }

  getAgentDashboard(params = {}) {
    return axios.get(`${this.url}/agent_dashboard`, { params });
  }

  getSupervisorDashboard(params = {}) {
    return axios.get(`${this.url}/supervisor_dashboard`, { params });
  }
}

export default new ChathubAnalyticsAPI();
