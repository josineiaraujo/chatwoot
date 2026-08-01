/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class ExternalMessagingAPI extends ApiClient {
  constructor() {
    super('ibsoft/external_messaging', { accountScoped: true });
  }

  getEndpoints() {
    return axios.get(`${this.url}/endpoints`);
  }

  createEndpoint(payload) {
    return axios.post(`${this.url}/endpoints`, payload);
  }

  updateEndpoint(endpointId, payload) {
    return axios.patch(`${this.url}/endpoints/${endpointId}`, payload);
  }

  deactivateEndpoint(endpointId) {
    return axios.delete(`${this.url}/endpoints/${endpointId}`);
  }

  rotateToken(endpointId) {
    return axios.post(`${this.url}/endpoints/${endpointId}/rotate_token`);
  }

  getDeliveries(params = {}) {
    return axios.get(`${this.url}/deliveries`, { params });
  }

  getOrders(params = {}) {
    return axios.get(`${this.url}/orders`, { params });
  }

  bulkUpdateOrders(payload) {
    return axios.post(`${this.url}/orders/bulk_update`, payload);
  }
}

export default new ExternalMessagingAPI();
