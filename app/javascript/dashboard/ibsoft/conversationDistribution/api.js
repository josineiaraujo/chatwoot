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

  getAutomationHandoffPolicy(inboxId) {
    return axios.get(`${this.url}/automation_handoff_policies/${inboxId}`);
  }

  updateAutomationHandoffPolicy(inboxId, payload) {
    return axios.patch(
      `${this.url}/automation_handoff_policies/${inboxId}`,
      payload
    );
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

  getTeamPolicy(teamId, policyInboxId = null) {
    return axios.get(`${this.url}/team_policies/${teamId}`, {
      params: { policy_inbox_id: policyInboxId },
    });
  }

  updateTeamPolicy(teamId, payload) {
    return axios.patch(`${this.url}/team_policies/${teamId}`, payload);
  }

  getEffectivePolicy({ inboxId, teamId }) {
    return axios.get(`${this.url}/effective_policy`, {
      params: { inbox_id: inboxId, team_id: teamId },
    });
  }

  getSupervisorAlerts(params = {}, config = {}) {
    return axios.get(`${this.url}/supervisor_alerts`, { ...config, params });
  }

  getEventLogs(params = {}) {
    return axios.get(`${this.url}/event_logs`, { params });
  }

  getAgentAssignments(params = {}) {
    return axios.get(`${this.url}/agent_assignments`, { params });
  }

  claimAgentAssignments(conversationIds) {
    return axios.post(`${this.url}/agent_assignments/claim`, {
      conversation_ids: conversationIds,
    });
  }

  manuallyAssignConversation(conversationId, assignmentType, targetId) {
    return axios.post(
      `${this.url}/conversations/${conversationId}/manual_assignment`,
      {
        assignment_type: assignmentType,
        target_id: targetId,
      }
    );
  }

  returnConversationToQueue(conversationId, teamId) {
    return axios.post(
      `${this.url}/conversations/${conversationId}/return_to_queue`,
      { team_id: teamId }
    );
  }
}

export default new ConversationDistributionAPI();
