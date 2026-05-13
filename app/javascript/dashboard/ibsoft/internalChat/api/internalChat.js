/* global axios */

import ApiClient from 'dashboard/api/ApiClient';

class InternalChatAPI extends ApiClient {
  constructor() {
    super('ibsoft/internal_chat/rooms', { accountScoped: true });
  }

  direct(targetUserId) {
    return axios.post(`${this.url}/direct`, { target_user_id: targetUserId });
  }

  unreadCount() {
    return axios.get(`${this.url}/unread_count`);
  }

  messages(roomId, params = {}) {
    return axios.get(`${this.url}/${roomId}/messages`, { params });
  }

  attachment(url) {
    const requestUrl = url.startsWith('/api/') ? url : `${this.url}/${url}`;
    return axios.get(requestUrl, { responseType: 'blob' });
  }

  sendMessage(roomId, { content, files }) {
    const formData = new FormData();
    formData.append('content', content || '');
    Array.from(files || []).forEach(file => {
      const uploadFile = file?.resource?.file || file?.file || file;
      if (uploadFile) formData.append('attachments[]', uploadFile);
    });

    return axios.post(`${this.url}/${roomId}/messages`, formData);
  }

  updateRoom(roomId, { name, coverImage }) {
    const formData = new FormData();
    formData.append('name', name || '');
    if (coverImage) formData.append('cover_image', coverImage);

    return axios.patch(`${this.url}/${roomId}`, formData);
  }

  deleteRoom(roomId) {
    return axios.delete(`${this.url}/${roomId}`);
  }

  markAsRead(roomId, messageId) {
    return axios.post(`${this.url}/${roomId}/read`, {
      message_id: messageId,
      read_context: 'active_room',
      active_room_id: roomId,
    });
  }

  addMembers(roomId, userIds) {
    return axios.post(`${this.url}/${roomId}/memberships`, {
      user_ids: userIds,
    });
  }

  removeMember(roomId, membershipId) {
    return axios.delete(`${this.url}/${roomId}/memberships/${membershipId}`);
  }
}

export default new InternalChatAPI();
