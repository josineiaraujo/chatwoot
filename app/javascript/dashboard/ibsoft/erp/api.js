/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class ErpAPI extends ApiClient {
  constructor() {
    super('ibsoft/erp', { accountScoped: true });
  }

  getConnections() {
    return axios.get(`${this.url}/connections`);
  }

  createConnection(payload) {
    return axios.post(`${this.url}/connections`, payload);
  }

  updateConnection(connectionId, payload) {
    return axios.patch(`${this.url}/connections/${connectionId}`, payload);
  }

  testConnection(connectionId) {
    return axios.post(
      `${this.url}/connections/${connectionId}/test_connection`
    );
  }

  deleteConnection(connectionId) {
    return axios.delete(`${this.url}/connections/${connectionId}`);
  }
}

export default new ErpAPI();
