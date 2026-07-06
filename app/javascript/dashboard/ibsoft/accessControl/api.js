/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class AccessControlAPI extends ApiClient {
  constructor() {
    super('ibsoft/access_control', { accountScoped: true });
  }

  getRoles() {
    return axios.get(`${this.url}/roles`);
  }

  createRole(payload) {
    return axios.post(`${this.url}/roles`, { role: payload });
  }

  updateRole(id, payload) {
    return axios.patch(`${this.url}/roles/${id}`, { role: payload });
  }

  deleteRole(id) {
    return axios.delete(`${this.url}/roles/${id}`);
  }

  getAssignments() {
    return axios.get(`${this.url}/role_assignments`);
  }

  saveAssignment({ userId, roleId }) {
    return axios.post(`${this.url}/role_assignments`, {
      user_id: userId,
      role_id: roleId,
    });
  }

  deleteAssignment(id) {
    return axios.delete(`${this.url}/role_assignments/${id}`);
  }
}

export default new AccessControlAPI();
