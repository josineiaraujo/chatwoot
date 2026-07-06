/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

const buildAgentPayload = payload => {
  if (!payload.avatar) {
    return { agent: payload };
  }

  const formData = new FormData();
  Object.entries(payload).forEach(([key, value]) => {
    if (value === null || value === undefined || value === '') return;
    formData.append(`agent[${key}]`, value);
  });

  return formData;
};

class AgentProvisioningAPI extends ApiClient {
  constructor() {
    super('ibsoft/agent_provisioning/agents', { accountScoped: true });
  }

  get nativeAgentsUrl() {
    return `${this.baseUrl()}/agents`;
  }

  get roleAssignmentsUrl() {
    return `${this.baseUrl()}/ibsoft/access_control/role_assignments`;
  }

  getAgents() {
    return axios.get(this.url);
  }

  createAgent(payload) {
    return axios.post(this.url, buildAgentPayload(payload));
  }

  updateAgent(id, payload) {
    return axios.patch(`${this.url}/${id}`, buildAgentPayload(payload));
  }

  deleteAgent(id) {
    return axios.delete(`${this.nativeAgentsUrl}/${id}`);
  }

  resetTemporaryPassword(id) {
    return axios.post(`${this.url}/${id}/reset_temporary_password`);
  }

  saveProfileAssignment({ userId, roleId }) {
    return axios.post(this.roleAssignmentsUrl, {
      user_id: userId,
      role_id: roleId,
    });
  }

  deleteProfileAssignment(assignmentId) {
    return axios.delete(`${this.roleAssignmentsUrl}/${assignmentId}`);
  }
}

export default new AgentProvisioningAPI();
