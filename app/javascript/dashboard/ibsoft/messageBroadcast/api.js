/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class MessageBroadcastAPI extends ApiClient {
  constructor() {
    super('ibsoft/message_broadcast', { accountScoped: true });
  }

  getGroups() {
    return axios.get(`${this.url}/groups`);
  }

  createGroup(payload) {
    return axios.post(`${this.url}/groups`, payload);
  }

  updateGroup(groupId, payload) {
    return axios.patch(`${this.url}/groups/${groupId}`, payload);
  }

  deleteGroup(groupId) {
    return axios.delete(`${this.url}/groups/${groupId}`);
  }

  getBroadcasts(params = {}) {
    return axios.get(`${this.url}/broadcasts`, { params });
  }

  getBroadcast(broadcastId) {
    return axios.get(`${this.url}/broadcasts/${broadcastId}`);
  }

  sendBroadcast(broadcastId) {
    return axios.post(`${this.url}/broadcasts/${broadcastId}/send_broadcast`);
  }

  getTemplates(params = {}) {
    return axios.get(`${this.url}/templates`, { params });
  }

  getStates(params = {}) {
    return axios.get(`${this.url}/lookups/states`, { params });
  }

  getCities(params = {}) {
    return axios.get(`${this.url}/lookups/cities`, { params });
  }

  getPlans(params = {}) {
    return axios.get(`${this.url}/lookups/plans`, { params });
  }

  getPops(params = {}) {
    return axios.get(`${this.url}/lookups/pops`, { params });
  }

  getTransmitters(params = {}) {
    return axios.get(`${this.url}/lookups/transmitters`, { params });
  }

  previewRecipients(payload) {
    return axios.post(`${this.url}/recipients/preview`, payload);
  }

  createBroadcast(payload) {
    return axios.post(`${this.url}/broadcasts`, payload);
  }
}

export default new MessageBroadcastAPI();
