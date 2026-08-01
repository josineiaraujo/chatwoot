/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class MetaTemplatesAPI extends ApiClient {
  constructor() {
    super('ibsoft/meta_templates', { accountScoped: true });
  }

  templateUrl(inboxId, templateId = '') {
    const suffix = templateId ? `/${encodeURIComponent(templateId)}` : '';
    return `${this.url}/inboxes/${inboxId}/templates${suffix}`;
  }

  getTemplates(inboxId, params = {}) {
    return axios.get(this.templateUrl(inboxId), { params });
  }

  getTemplate(inboxId, templateId) {
    return axios.get(this.templateUrl(inboxId, templateId));
  }

  createTemplate(inboxId, template) {
    return axios.post(this.templateUrl(inboxId), { template });
  }

  updateTemplate(inboxId, templateId, template) {
    return axios.patch(this.templateUrl(inboxId, templateId), { template });
  }

  deleteTemplate(inboxId, templateId) {
    return axios.delete(this.templateUrl(inboxId, templateId));
  }

  uploadMedia(inboxId, file, onUploadProgress) {
    const formData = new FormData();
    formData.append('file', file);

    return axios.post(
      `${this.url}/inboxes/${inboxId}/media_uploads`,
      formData,
      {
        onUploadProgress,
      }
    );
  }
}

export default new MetaTemplatesAPI();
