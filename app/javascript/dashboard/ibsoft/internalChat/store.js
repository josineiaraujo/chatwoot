import InternalChatAPI from './api/internalChat';

const roomIdKey = roomId => String(roomId);

const hasUnreadMessages = room => Number(room?.unread_count) > 0;

const unreadRoomMapFromRooms = rooms =>
  (rooms || []).reduce((acc, room) => {
    if (hasUnreadMessages(room)) {
      acc[roomIdKey(room.id)] = true;
    }
    return acc;
  }, {});

const state = {
  unreadRoomIds: {},
  unreadRoomCount: 0,
  hasRoomUnreadSnapshot: false,
  activeRoomId: null,
};

export const getters = {
  getUnreadRoomCount($state) {
    return $state.unreadRoomCount;
  },
  getActiveRoomId($state) {
    return $state.activeRoomId;
  },
};

export const actions = {
  async fetchUnreadRoomCount({ commit }) {
    try {
      const { data } = await InternalChatAPI.unreadCount();
      commit('SET_UNREAD_ROOM_COUNT', data);
    } catch {
      // The sidebar should not fail if the internal chat endpoint is not ready.
    }
  },
  setRooms({ commit }, rooms) {
    commit('SET_UNREAD_ROOMS_FROM_ROOMS', rooms);
  },
  setActiveRoom({ commit }, roomId) {
    commit('SET_ACTIVE_ROOM', roomId);
  },
  clearActiveRoom({ commit }) {
    commit('SET_ACTIVE_ROOM', null);
  },
  markRoomAsRead({ commit }, roomId) {
    commit('MARK_ROOM_AS_READ', roomId);
  },
  removeRoom({ commit, dispatch, state: moduleState }, roomId) {
    commit('MARK_ROOM_AS_READ', roomId);
    if (!moduleState.hasRoomUnreadSnapshot) dispatch('fetchUnreadRoomCount');
  },
  roomUpdated({ commit, dispatch, state: moduleState }, room) {
    if (!room?.id) return;

    if (!moduleState.hasRoomUnreadSnapshot) {
      dispatch('fetchUnreadRoomCount');
      return;
    }

    commit('SET_ROOM_UNREAD_STATUS', {
      roomId: room.id,
      hasUnread: hasUnreadMessages(room),
    });
  },
  messageCreated(
    { commit, dispatch, rootGetters, state: moduleState },
    payload
  ) {
    const roomId = payload?.room_id;
    if (!roomId) return;

    const currentUserId = rootGetters.getCurrentUser?.id;
    const senderId = payload?.message?.sender?.id;
    const isCurrentUserMessage =
      currentUserId && senderId && Number(currentUserId) === Number(senderId);
    const isActiveRoom =
      moduleState.activeRoomId &&
      Number(moduleState.activeRoomId) === Number(roomId);

    if (isCurrentUserMessage || isActiveRoom) {
      commit('MARK_ROOM_AS_READ', roomId);
      return;
    }

    if (!moduleState.hasRoomUnreadSnapshot) {
      dispatch('fetchUnreadRoomCount');
      return;
    }

    if (payload.room) {
      commit('SET_ROOM_UNREAD_STATUS', {
        roomId,
        hasUnread: hasUnreadMessages(payload.room),
      });
      return;
    }

    commit('MARK_ROOM_AS_UNREAD', roomId);
  },
};

export const mutations = {
  SET_UNREAD_ROOM_COUNT($state, count) {
    $state.unreadRoomCount = Number(count) || 0;
  },
  SET_UNREAD_ROOMS_FROM_ROOMS($state, rooms) {
    $state.unreadRoomIds = unreadRoomMapFromRooms(rooms);
    $state.unreadRoomCount = Object.keys($state.unreadRoomIds).length;
    $state.hasRoomUnreadSnapshot = true;
  },
  SET_ACTIVE_ROOM($state, roomId) {
    $state.activeRoomId = roomId ? Number(roomId) : null;
  },
  SET_ROOM_UNREAD_STATUS($state, { roomId, hasUnread }) {
    const key = roomIdKey(roomId);
    const hadUnread = !!$state.unreadRoomIds[key];

    if (hasUnread) {
      $state.unreadRoomIds = {
        ...$state.unreadRoomIds,
        [key]: true,
      };
      if (!hadUnread) $state.unreadRoomCount += 1;
      return;
    }

    const nextUnreadRoomIds = { ...$state.unreadRoomIds };
    delete nextUnreadRoomIds[key];
    $state.unreadRoomIds = nextUnreadRoomIds;
    if (hadUnread) {
      $state.unreadRoomCount = Math.max(0, $state.unreadRoomCount - 1);
    }
  },
  MARK_ROOM_AS_UNREAD($state, roomId) {
    const key = roomIdKey(roomId);
    const hadUnread = !!$state.unreadRoomIds[key];

    $state.unreadRoomIds = {
      ...$state.unreadRoomIds,
      [key]: true,
    };
    if (!hadUnread) $state.unreadRoomCount += 1;
  },
  MARK_ROOM_AS_READ($state, roomId) {
    const key = roomIdKey(roomId);
    const hadUnread = !!$state.unreadRoomIds[key];
    const nextUnreadRoomIds = { ...$state.unreadRoomIds };
    delete nextUnreadRoomIds[key];
    $state.unreadRoomIds = nextUnreadRoomIds;
    if (hadUnread) {
      $state.unreadRoomCount = Math.max(0, $state.unreadRoomCount - 1);
    }
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
