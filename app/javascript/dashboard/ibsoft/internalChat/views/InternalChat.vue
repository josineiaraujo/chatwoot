<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useElementSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useI18n } from 'vue-i18n';
import { onBeforeRouteLeave, useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import UnreadBadge from 'dashboard/components-next/Conversation/ConversationCard/UnreadBadge.vue';
import ResizableEditorWrapper from 'dashboard/components/widgets/conversation/ResizableEditorWrapper.vue';
import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import InternalChatComposer from '../components/InternalChatComposer.vue';
import InternalChatAudioChip from '../components/InternalChatAudioChip.vue';
import MediaPreviewModal from '../components/MediaPreviewModal.vue';
import InternalChatAPI from '../api/internalChat';
import {
  clearActiveInternalChatRoom,
  setActiveInternalChatRoom,
} from '../helpers/audioNotifications';
import {
  buildMessageDateGroups,
  formatMessageTimestamp,
  isSameLocalDate,
} from '../helpers/messageDateGroups';

const { t, locale } = useI18n();
const store = useStore();
const route = useRoute();
const currentUser = useMapGetter('getCurrentUser');
const agents = useMapGetter('agents/getAgents');
const MESSAGE_PAGE_SIZE = 50;
const MESSAGE_SCROLL_TOP_THRESHOLD = 80;
const MESSAGE_SCROLL_BOTTOM_THRESHOLD = 120;

const rooms = ref([]);
const messages = ref([]);
const selectedRoomId = ref(null);
const composerText = ref('');
const selectedAttachments = ref([]);
const roomSearchQuery = ref('');
const directSearchQuery = ref('');
const roomFilter = ref('all');
const createRoomName = ref('');
const createMemberIds = ref([]);
const editRoomName = ref('');
const editMemberIds = ref([]);
const editCoverImageFile = ref(null);
const editCoverPreviewUrl = ref('');
const coverCropImageUrl = ref('');
const coverCropZoom = ref(1);
const selectedMediaAttachment = ref(null);
const isCreateRoomModalOpen = ref(false);
const isDirectChatModalOpen = ref(false);
const isEditRoomModalOpen = ref(false);
const isDeleteRoomConfirmOpen = ref(false);
const isMediaPreviewOpen = ref(false);
const isCreateMenuOpen = ref(false);
const isLoadingRooms = ref(false);
const isLoadingMessages = ref(false);
const isLoadingOlderMessages = ref(false);
const hasMoreMessages = ref(false);
const isSavingRoom = ref(false);
const isSendingMessage = ref(false);
const errorMessage = ref('');
const coverImageInput = ref(null);
const chatPanel = ref(null);
const chatHeader = ref(null);
const errorPanel = ref(null);
const messagesPanel = ref(null);
const resizableEditorWrapper = ref(null);
const shouldPinMessagesToBottom = ref(false);
const attachmentObjectUrls = ref({});
let pinMessagesToBottomTimer = null;
let roomSelectionToken = 0;
let attachmentObjectUrlGeneration = 0;
const attachmentObjectUrlRequests = new Map();

const { height: chatPanelHeight } = useElementSize(chatPanel);
const { height: chatHeaderHeight } = useElementSize(chatHeader);
const { height: errorPanelHeight } = useElementSize(errorPanel);

const composerContainerHeight = computed(() =>
  Math.max(
    0,
    chatPanelHeight.value - chatHeaderHeight.value - errorPanelHeight.value
  )
);

const selectedRoom = computed(() =>
  rooms.value.find(room => room.id === selectedRoomId.value)
);

const availableAgents = computed(() =>
  agents.value.filter(agent => agent.id !== currentUser.value?.id)
);

const selectedRoomMembers = computed(() => selectedRoom.value?.members || []);

const currentRoomMemberIds = computed(() =>
  selectedRoomMembers.value.map(member => member.id)
);

const canUpdateSelectedRoomCover = computed(
  () => !!selectedRoom.value?.permissions?.update_cover_image
);

const canManageSelectedRoomMembers = computed(
  () => !!selectedRoom.value?.permissions?.manage_members
);

const canDestroySelectedRoom = computed(
  () => !!selectedRoom.value?.permissions?.destroy
);

const isDirectRoom = room => room?.room_type === 'direct';

const isCurrentUserRoomMember = room =>
  !!room?.members?.some(member => member.id === currentUser.value?.id);

const canPostSelectedRoom = computed(
  () => !!selectedRoom.value && isCurrentUserRoomMember(selectedRoom.value)
);

const deleteSelectedChatLabel = computed(() =>
  isDirectRoom(selectedRoom.value)
    ? t('IBSOFT_INTERNAL_CHAT.ACTIONS.DELETE_CHAT')
    : t('IBSOFT_INTERNAL_CHAT.ACTIONS.DELETE_ROOM')
);

const deleteSelectedChatConfirm = computed(() =>
  isDirectRoom(selectedRoom.value)
    ? t('IBSOFT_INTERNAL_CHAT.ROOMS.DELETE_CHAT_CONFIRM')
    : t('IBSOFT_INTERNAL_CHAT.ROOMS.DELETE_CONFIRM')
);

const directRoomPeer = room =>
  room?.members?.find(member => member.id !== currentUser.value?.id);

const agentById = id => agents.value.find(agent => agent.id === id);

const agentDisplayName = user => {
  const agent = agentById(user?.id);
  return (
    agent?.available_name ||
    agent?.name ||
    user?.available_name ||
    user?.name ||
    ''
  );
};

const agentAvailabilityStatus = user => {
  const agent = agentById(user?.id);
  if (agent?.availability_status) return agent.availability_status;

  if (user?.id === currentUser.value?.id) {
    return (
      currentUser.value?.availability_status ||
      currentUser.value?.availability ||
      user?.availability_status ||
      'offline'
    );
  }

  return user?.availability_status || 'offline';
};

const roomDisplayName = room => {
  if (!isDirectRoom(room)) return room?.name || room?.display_name || '';

  const peer = directRoomPeer(room);
  return agentDisplayName(peer) || room?.display_name || '';
};

const normalizeAvatarUrl = url => {
  if (!url) return '';

  try {
    const parsedUrl = new URL(url, window.location.origin);
    if (parsedUrl.hostname === '0.0.0.0') {
      return `${window.location.origin}${parsedUrl.pathname}${parsedUrl.search}`;
    }

    return url;
  } catch {
    return url;
  }
};

const avatarSrc = item =>
  normalizeAvatarUrl(item?.thumbnail || item?.avatar_url || '');

const agentAvatarSrc = user => avatarSrc(agentById(user?.id) || user);

const roomAvatarSrc = room => agentAvatarSrc(directRoomPeer(room));

const roomAvailabilityStatus = room =>
  agentAvailabilityStatus(directRoomPeer(room));

const roomCoverImageSrc = room =>
  normalizeAvatarUrl(room?.cover_image_url || '');

const roomMembersLabel = computed(() => {
  if (!selectedRoom.value || selectedRoom.value.room_type !== 'room') return '';

  const count = selectedRoomMembers.value.length;
  return t('IBSOFT_INTERNAL_CHAT.HEADER.MEMBERS', { count });
});

const canSendMessage = computed(
  () =>
    canPostSelectedRoom.value &&
    (composerText.value.trim().length > 0 ||
      selectedAttachments.value.length > 0)
);

const filteredRooms = computed(() => {
  const query = roomSearchQuery.value.trim().toLowerCase();

  return rooms.value.filter(room => {
    const matchesFilter =
      roomFilter.value === 'all' || room.room_type === roomFilter.value;
    const matchesSearch =
      !query ||
      roomDisplayName(room)?.toLowerCase().includes(query) ||
      room.last_message?.content?.toLowerCase().includes(query);

    return matchesFilter && matchesSearch;
  });
});

const filteredAgents = computed(() => {
  const query = directSearchQuery.value.trim().toLowerCase();
  if (!query) return availableAgents.value;

  return availableAgents.value.filter(agent =>
    (agent.available_name || agent.name || '').toLowerCase().includes(query)
  );
});

const addableAgents = computed(() => {
  const existingIds = new Set(currentRoomMemberIds.value);
  return availableAgents.value.map(agent => ({
    ...agent,
    isCurrentMember: existingIds.has(agent.id),
  }));
});

const roomMemberCandidates = computed(() =>
  addableAgents.value.filter(agent => !agent.isCurrentMember)
);

const isOwnMessage = message => message.sender?.id === currentUser.value?.id;

const isPreviewableMediaAttachment = attachment =>
  ['image', 'video'].includes(attachment?.file_type);

const attachmentUrl = url => normalizeAvatarUrl(url);

const protectedAttachmentUrl = (attachment, variant = 'source') => {
  const url =
    variant === 'preview'
      ? attachment?.preview_url || attachment?.url
      : attachment?.url;

  return attachmentUrl(url || '');
};

const attachmentObjectUrlKey = (attachment, variant = 'source') =>
  `${attachment?.id || 'unknown'}:${variant}:${protectedAttachmentUrl(attachment, variant)}`;

const attachmentObjectUrl = (attachment, variant = 'source') =>
  attachmentObjectUrls.value[attachmentObjectUrlKey(attachment, variant)] || '';

const attachmentSourceUrl = attachment => attachmentObjectUrl(attachment);

const attachmentPreviewUrl = attachment =>
  attachmentObjectUrl(attachment, 'preview') ||
  (attachment?.file_type === 'image' ? attachmentObjectUrl(attachment) : '');

const fetchAttachmentObjectUrl = async (attachment, variant = 'source') => {
  const url = protectedAttachmentUrl(attachment, variant);
  if (!url) return '';

  const key = attachmentObjectUrlKey(attachment, variant);
  if (attachmentObjectUrls.value[key]) return attachmentObjectUrls.value[key];
  if (attachmentObjectUrlRequests.has(key)) {
    return attachmentObjectUrlRequests.get(key);
  }

  const generation = attachmentObjectUrlGeneration;
  const request = InternalChatAPI.attachment(url)
    .then(({ data }) => {
      const objectUrl = URL.createObjectURL(data);
      if (generation !== attachmentObjectUrlGeneration) {
        URL.revokeObjectURL(objectUrl);
        return '';
      }

      attachmentObjectUrls.value = {
        ...attachmentObjectUrls.value,
        [key]: objectUrl,
      };
      return objectUrl;
    })
    .catch(() => '')
    .finally(() => {
      attachmentObjectUrlRequests.delete(key);
    });

  attachmentObjectUrlRequests.set(key, request);
  return request;
};

const warmAttachmentMedia = messageList => {
  messageList.forEach(message => {
    (message.attachments || []).forEach(attachment => {
      if (attachment.file_type === 'image') {
        fetchAttachmentObjectUrl(attachment, 'preview');
      }

      if (attachment.file_type === 'video' && attachment.preview_url) {
        fetchAttachmentObjectUrl(attachment, 'preview');
      }
    });
  });
};

const revokeAttachmentObjectUrls = () => {
  attachmentObjectUrlGeneration += 1;
  Object.values(attachmentObjectUrls.value).forEach(objectUrl => {
    URL.revokeObjectURL(objectUrl);
  });
  attachmentObjectUrls.value = {};
  attachmentObjectUrlRequests.clear();
};

const galleryAttachment = (attachment, message) => ({
  ...attachment,
  message_id: attachment.id,
  data_url: attachmentSourceUrl(attachment),
  thumb_url: attachmentPreviewUrl(attachment),
  source_url: protectedAttachmentUrl(attachment),
  preview_url: protectedAttachmentUrl(attachment, 'preview'),
  created_at: message.created_at,
  sender: {
    ...message.sender,
    id: null,
    name: isOwnMessage(message)
      ? t('IBSOFT_INTERNAL_CHAT.MESSAGES.YOU')
      : agentDisplayName(message.sender),
  },
  extension: attachment.file_name?.split('.').pop() || '',
});

const mediaGalleryAttachments = computed(() =>
  messages.value.flatMap(message =>
    (message.attachments || [])
      .filter(isPreviewableMediaAttachment)
      .map(attachment => galleryAttachment(attachment, message))
  )
);

const messageDateGroups = computed(() =>
  buildMessageDateGroups(messages.value, {
    locale: locale.value,
    todayLabel: t('IBSOFT_INTERNAL_CHAT.MESSAGES.TODAY'),
  })
);

const createMenuItems = computed(() => [
  {
    action: 'newDirectChat',
    label: t('IBSOFT_INTERNAL_CHAT.ACTIONS.NEW_CONVERSATION'),
    icon: 'i-lucide-message-circle-plus',
  },
  {
    action: 'createRoom',
    label: t('IBSOFT_INTERNAL_CHAT.ACTIONS.CREATE_NEW_ROOM'),
    icon: 'i-lucide-users-round',
  },
]);

const formatTime = value => {
  if (!value) return '';

  return new Intl.DateTimeFormat(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const formatInternalMessageTime = value =>
  formatMessageTimestamp(value, { locale: locale.value });

const roomIcon = room =>
  isDirectRoom(room)
    ? 'i-lucide-user-round size-4'
    : 'i-lucide-users-round size-4';

const roomPreview = room => {
  if (room.last_message?.content) return room.last_message.content;
  if (room.last_message?.attachments?.length) {
    return t('IBSOFT_INTERNAL_CHAT.ROOMS.ATTACHMENT_PREVIEW');
  }

  return t('IBSOFT_INTERNAL_CHAT.ROOMS.NO_MESSAGES');
};

const roomUnreadCount = room => Number(room?.unread_count) || 0;

const hasUnreadRoomMessages = room => roomUnreadCount(room) > 0;

const activeRoomId = computed(
  () => store.getters['ibsoftInternalChat/getActiveRoomId']
);

const isCurrentRoomOpen = roomId =>
  route.name === 'ibsoft_internal_chat' &&
  Number(selectedRoomId.value) === Number(roomId) &&
  Number(activeRoomId.value) === Number(roomId);

const upsertRoom = room => {
  const index = rooms.value.findIndex(item => item.id === room.id);
  if (index === -1) {
    rooms.value = [room, ...rooms.value];
    return;
  }

  rooms.value.splice(index, 1, room);
};

const promoteRoomWithMessage = (
  roomId,
  message,
  { markAsRead = false, roomPayload = null } = {}
) => {
  const index = rooms.value.findIndex(room => room.id === roomId);
  if (index === -1 && !roomPayload) return false;

  const room =
    index === -1 ? roomPayload : { ...rooms.value[index], ...roomPayload };
  const currentUnreadCount = roomUnreadCount(room);
  const unreadCount = markAsRead
    ? 0
    : (roomPayload?.unread_count ?? currentUnreadCount + 1);
  const updatedRoom = {
    ...room,
    unread_count: unreadCount,
    last_message: message,
    updated_at: message.created_at || room.updated_at,
  };

  rooms.value =
    index === -1
      ? [updatedRoom, ...rooms.value]
      : [
          updatedRoom,
          ...rooms.value.slice(0, index),
          ...rooms.value.slice(index + 1),
        ];
  return true;
};

const setMessagesPanelToBottom = () => {
  if (!messagesPanel.value) return;

  messagesPanel.value.scrollTop = messagesPanel.value.scrollHeight;
};

const pinMessagesToBottom = () => {
  shouldPinMessagesToBottom.value = true;
  if (pinMessagesToBottomTimer) clearTimeout(pinMessagesToBottomTimer);

  pinMessagesToBottomTimer = window.setTimeout(() => {
    shouldPinMessagesToBottom.value = false;
    pinMessagesToBottomTimer = null;
  }, 1200);
};

const scrollToLatestMessage = ({ pin = false } = {}) => {
  if (pin) pinMessagesToBottom();

  nextTick(() => {
    setMessagesPanelToBottom();
    window.requestAnimationFrame(() => {
      setMessagesPanelToBottom();
      window.requestAnimationFrame(setMessagesPanelToBottom);
    });
    window.setTimeout(setMessagesPanelToBottom, 120);
    window.setTimeout(setMessagesPanelToBottom, 360);
  });
};

const toggleComposerHeight = () => {
  resizableEditorWrapper.value?.toggleEditorExpand?.();
};

const resetComposerHeight = () => {
  resizableEditorWrapper.value?.resetEditorHeight?.();
};

const isMessagesPanelNearBottom = () => {
  if (!messagesPanel.value) return true;

  const distanceFromBottom =
    messagesPanel.value.scrollHeight -
    messagesPanel.value.scrollTop -
    messagesPanel.value.clientHeight;

  return distanceFromBottom <= MESSAGE_SCROLL_BOTTOM_THRESHOLD;
};

const keepMessagesPinnedToBottom = () => {
  if (!shouldPinMessagesToBottom.value && !isMessagesPanelNearBottom()) return;

  scrollToLatestMessage();
};

const nextRoomSelectionToken = () => {
  roomSelectionToken += 1;
  return roomSelectionToken;
};

const isCurrentRoomSelection = (selectionToken, roomId) =>
  selectionToken === roomSelectionToken &&
  Number(selectedRoomId.value) === Number(roomId);

const normalizeMessagesResponse = data => {
  if (Array.isArray(data)) {
    return {
      messages: data,
      hasMore: data.length >= MESSAGE_PAGE_SIZE,
    };
  }

  return {
    messages: data?.messages || [],
    hasMore: !!data?.meta?.has_more,
  };
};

const clearError = () => {
  errorMessage.value = '';
};

const fetchAgents = async () => {
  await store.dispatch('agents/get');
};

const fetchMessages = async (roomId, selectionToken = roomSelectionToken) => {
  isLoadingMessages.value = true;
  hasMoreMessages.value = false;
  try {
    const { data } = await InternalChatAPI.messages(roomId);
    if (!isCurrentRoomSelection(selectionToken, roomId)) return false;

    const payload = normalizeMessagesResponse(data);
    messages.value = payload.messages;
    hasMoreMessages.value = payload.hasMore;
    warmAttachmentMedia(messages.value);
    scrollToLatestMessage({ pin: true });
    return true;
  } finally {
    if (isCurrentRoomSelection(selectionToken, roomId)) {
      isLoadingMessages.value = false;
    }
  }
};

const loadOlderMessages = async () => {
  if (
    !selectedRoom.value ||
    isLoadingMessages.value ||
    isLoadingOlderMessages.value ||
    !hasMoreMessages.value ||
    !messages.value.length
  ) {
    return;
  }

  const roomId = selectedRoom.value.id;
  const beforeId = messages.value[0].id;
  const previousScrollHeight = messagesPanel.value?.scrollHeight || 0;
  const previousScrollTop = messagesPanel.value?.scrollTop || 0;

  isLoadingOlderMessages.value = true;
  try {
    const { data } = await InternalChatAPI.messages(roomId, {
      before_id: beforeId,
    });
    if (roomId !== selectedRoomId.value) return;

    const payload = normalizeMessagesResponse(data);
    const currentMessageIds = new Set(
      messages.value.map(message => message.id)
    );
    const olderMessages = payload.messages.filter(
      message => !currentMessageIds.has(message.id)
    );

    messages.value = [...olderMessages, ...messages.value];
    hasMoreMessages.value = payload.hasMore;
    warmAttachmentMedia(olderMessages);

    await nextTick();
    if (!messagesPanel.value) return;

    messagesPanel.value.scrollTop =
      messagesPanel.value.scrollHeight -
      previousScrollHeight +
      previousScrollTop;
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.LOAD_MESSAGES');
  } finally {
    isLoadingOlderMessages.value = false;
  }
};

const handleMessagesScroll = event => {
  if (!isMessagesPanelNearBottom()) {
    shouldPinMessagesToBottom.value = false;
  }

  if (event.target.scrollTop > MESSAGE_SCROLL_TOP_THRESHOLD) return;

  loadOlderMessages();
};

const markRoomAsRead = async (roomId, messageId) => {
  try {
    await InternalChatAPI.markAsRead(roomId, messageId);
  } catch {
    // Read sync is best-effort and must not make a delivered message look failed.
  }
};

const selectRoom = async room => {
  const selectionToken = nextRoomSelectionToken();
  revokeAttachmentObjectUrls();
  selectedRoomId.value = room.id;
  store.dispatch('ibsoftInternalChat/setActiveRoom', room.id);
  const didLoadMessages = await fetchMessages(room.id, selectionToken);
  if (!didLoadMessages || !isCurrentRoomSelection(selectionToken, room.id)) {
    return;
  }

  const lastMessage = messages.value[messages.value.length - 1];
  if (isCurrentUserRoomMember(room)) {
    await markRoomAsRead(room.id, lastMessage?.id);
  }
  upsertRoom({ ...room, unread_count: 0 });
  store.dispatch('ibsoftInternalChat/markRoomAsRead', room.id);
};

const fetchRooms = async () => {
  isLoadingRooms.value = true;
  try {
    const { data } = await InternalChatAPI.get();
    rooms.value = data;
    store.dispatch('ibsoftInternalChat/setRooms', data);
  } finally {
    isLoadingRooms.value = false;
  }
};

const closeCreateMenu = () => {
  isCreateMenuOpen.value = false;
};

const toggleCreateMenu = () => {
  isCreateMenuOpen.value = !isCreateMenuOpen.value;
};

const openCreateRoomModal = () => {
  clearError();
  closeCreateMenu();
  createRoomName.value = '';
  createMemberIds.value = [];
  isCreateRoomModalOpen.value = true;
};

const closeCreateRoomModal = () => {
  isCreateRoomModalOpen.value = false;
};

const openDirectChatModal = () => {
  clearError();
  closeCreateMenu();
  directSearchQuery.value = '';
  isDirectChatModalOpen.value = true;
};

const closeDirectChatModal = () => {
  isDirectChatModalOpen.value = false;
};

const onCreateMenuAction = ({ action }) => {
  if (action === 'newDirectChat') {
    openDirectChatModal();
    return;
  }

  if (action === 'createRoom') {
    openCreateRoomModal();
  }
};

const clearCoverCrop = () => {
  coverCropImageUrl.value = '';
  coverCropZoom.value = 1;
  if (coverImageInput.value) coverImageInput.value.value = '';
};

const resetCoverImageEditor = room => {
  editCoverImageFile.value = null;
  editCoverPreviewUrl.value = roomCoverImageSrc(room);
  clearCoverCrop();
};

const onCoverImageSelected = event => {
  const [file] = event.target.files || [];
  if (!file) return;

  coverCropImageUrl.value = URL.createObjectURL(file);
  coverCropZoom.value = 1;
};

const loadImage = src =>
  new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = src;
  });

const applyCoverCrop = async () => {
  if (!coverCropImageUrl.value) return;

  const image = await loadImage(coverCropImageUrl.value);
  const canvas = document.createElement('canvas');
  const size = 512;
  const zoom = Number(coverCropZoom.value) || 1;
  const cropSize = Math.min(image.naturalWidth, image.naturalHeight) / zoom;
  const sourceX = (image.naturalWidth - cropSize) / 2;
  const sourceY = (image.naturalHeight - cropSize) / 2;

  canvas.width = size;
  canvas.height = size;

  const context = canvas.getContext('2d');
  context.drawImage(
    image,
    sourceX,
    sourceY,
    cropSize,
    cropSize,
    0,
    0,
    size,
    size
  );

  const blob = await new Promise(resolve => {
    canvas.toBlob(resolve, 'image/jpeg', 0.92);
  });
  if (!blob) return;

  editCoverImageFile.value = new File([blob], 'room-cover.jpg', {
    type: 'image/jpeg',
  });
  editCoverPreviewUrl.value = URL.createObjectURL(editCoverImageFile.value);
  clearCoverCrop();
};

const openEditRoomModal = () => {
  if (
    !selectedRoom.value ||
    selectedRoom.value.room_type === 'direct' ||
    !canUpdateSelectedRoomCover.value
  ) {
    return;
  }

  clearError();
  editRoomName.value =
    selectedRoom.value.name || selectedRoom.value.display_name;
  editMemberIds.value = selectedRoomMembers.value.map(member => member.id);
  resetCoverImageEditor(selectedRoom.value);
  isEditRoomModalOpen.value = true;
};

const closeEditRoomModal = () => {
  isEditRoomModalOpen.value = false;
  isDeleteRoomConfirmOpen.value = false;
  clearCoverCrop();
};

const createRoom = async () => {
  if (!createRoomName.value.trim()) return;

  isSavingRoom.value = true;
  clearError();
  try {
    const { data } = await InternalChatAPI.create({
      name: createRoomName.value,
      user_ids: createMemberIds.value,
    });
    closeCreateRoomModal();
    upsertRoom(data);
    await selectRoom(data);
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.CREATE_ROOM');
  } finally {
    isSavingRoom.value = false;
  }
};

const updateRoom = async () => {
  if (!selectedRoom.value || !editRoomName.value.trim()) return;

  isSavingRoom.value = true;
  clearError();
  try {
    const currentMemberIds = new Set(currentRoomMemberIds.value);
    const newMemberIds = canManageSelectedRoomMembers.value
      ? editMemberIds.value.filter(memberId => !currentMemberIds.has(memberId))
      : [];
    const { data: updatedRoom } = await InternalChatAPI.updateRoom(
      selectedRoom.value.id,
      {
        name: editRoomName.value,
        coverImage: editCoverImageFile.value,
      }
    );

    let room = updatedRoom;
    if (newMemberIds.length) {
      const { data } = await InternalChatAPI.addMembers(
        selectedRoom.value.id,
        newMemberIds
      );
      room = data;
    }

    closeEditRoomModal();
    upsertRoom(room);
    selectedRoomId.value = room.id;
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.UPDATE_ROOM');
  } finally {
    isSavingRoom.value = false;
  }
};

const removeRoomMember = async member => {
  if (!selectedRoom.value || !canManageSelectedRoomMembers.value) return;
  if (member.is_creator || !member.membership_id) return;

  isSavingRoom.value = true;
  clearError();
  try {
    const { data } = await InternalChatAPI.removeMember(
      selectedRoom.value.id,
      member.membership_id
    );
    upsertRoom(data);
    selectedRoomId.value = data.id;
    editMemberIds.value = data.members.map(item => item.id);
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.REMOVE_MEMBER');
  } finally {
    isSavingRoom.value = false;
  }
};

const openDeleteRoomConfirm = () => {
  if (!selectedRoom.value || !canDestroySelectedRoom.value) return;

  isDeleteRoomConfirmOpen.value = true;
};

const closeDeleteRoomConfirm = () => {
  isDeleteRoomConfirmOpen.value = false;
};

const removeRoomLocally = async roomId => {
  const wasSelectedRoom = selectedRoomId.value === roomId;

  rooms.value = rooms.value.filter(room => room.id !== roomId);
  store.dispatch('ibsoftInternalChat/removeRoom', roomId);
  if (!wasSelectedRoom) return;

  messages.value = [];
  composerText.value = '';
  selectedAttachments.value = [];
  closeEditRoomModal();

  selectedRoomId.value = null;
};

const deleteRoom = async () => {
  if (!selectedRoom.value || !canDestroySelectedRoom.value) return;

  const deletedRoomId = selectedRoom.value.id;
  const deleteErrorMessage = isDirectRoom(selectedRoom.value)
    ? t('IBSOFT_INTERNAL_CHAT.ERRORS.DELETE_CHAT')
    : t('IBSOFT_INTERNAL_CHAT.ERRORS.DELETE_ROOM');
  isSavingRoom.value = true;
  clearError();
  try {
    await InternalChatAPI.deleteRoom(deletedRoomId);
    await removeRoomLocally(deletedRoomId);
  } catch (error) {
    errorMessage.value = error.response?.data?.error || deleteErrorMessage;
  } finally {
    isSavingRoom.value = false;
  }
};

const startDirectChat = async agent => {
  clearError();
  try {
    const { data } = await InternalChatAPI.direct(agent.id);
    closeDirectChatModal();
    upsertRoom(data);
    await selectRoom(data);
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.DIRECT_ROOM');
  }
};

const appendMessage = (message, { scrollToBottom = true } = {}) => {
  if (messages.value.some(item => item.id === message.id)) return;

  messages.value.push(message);
  warmAttachmentMedia([message]);
  if (scrollToBottom) scrollToLatestMessage({ pin: true });
};

const sendMessage = async () => {
  if (!selectedRoom.value || !canSendMessage.value) return;

  isSendingMessage.value = true;
  clearError();
  try {
    const { data } = await InternalChatAPI.sendMessage(selectedRoom.value.id, {
      content: composerText.value,
      files: selectedAttachments.value,
    });
    composerText.value = '';
    selectedAttachments.value = [];
    resetComposerHeight();
    appendMessage(data);
    promoteRoomWithMessage(selectedRoom.value.id, data, { markAsRead: true });
    store.dispatch('ibsoftInternalChat/markRoomAsRead', selectedRoom.value.id);
    await markRoomAsRead(selectedRoom.value.id, data.id);
  } catch (error) {
    errorMessage.value =
      error.response?.data?.error ||
      t('IBSOFT_INTERNAL_CHAT.ERRORS.SEND_MESSAGE');
  } finally {
    isSendingMessage.value = false;
  }
};

const openMediaPreview = async (attachment, message) => {
  selectedMediaAttachment.value = galleryAttachment(attachment, message);
  isMediaPreviewOpen.value = true;
  await fetchAttachmentObjectUrl(attachment);
  selectedMediaAttachment.value = galleryAttachment(attachment, message);
};

const closeMediaPreview = () => {
  isMediaPreviewOpen.value = false;
  selectedMediaAttachment.value = null;
};

const onRealtimeMessage = async event => {
  const payload = event.detail;
  if (!payload?.room_id) return;

  const isSelectedRoom = isCurrentRoomOpen(payload.room_id);
  const isCurrentUserMessage =
    payload.message?.sender?.id === currentUser.value?.id;
  const roomWasUpdated = promoteRoomWithMessage(
    payload.room_id,
    payload.message,
    {
      markAsRead: isSelectedRoom || isCurrentUserMessage,
      roomPayload: payload.room,
    }
  );

  if (!roomWasUpdated) {
    await fetchRooms();
    return;
  }

  if (isSelectedRoom) {
    const shouldScrollToBottom =
      isCurrentUserMessage || isMessagesPanelNearBottom();

    appendMessage(payload.message, { scrollToBottom: shouldScrollToBottom });
    if (isCurrentUserRoomMember(selectedRoom.value)) {
      await markRoomAsRead(payload.room_id, payload.message.id);
      store.dispatch('ibsoftInternalChat/markRoomAsRead', payload.room_id);
    }
  }
};

const onRealtimeRoomUpdated = event => {
  const room = event.detail?.room;
  if (!room?.id) return;

  upsertRoom(room);
  store.dispatch('ibsoftInternalChat/roomUpdated', room);
};

const onRealtimeRoomRemoved = async event => {
  const roomId = event.detail?.room_id;
  if (!roomId) return;

  await removeRoomLocally(roomId);
};

const realtimeEventHandlers = [
  ['ibsoft:internal-chat:message-created', onRealtimeMessage],
  ['ibsoft:internal-chat:room-updated', onRealtimeRoomUpdated],
  ['ibsoft:internal-chat:room-deleted', onRealtimeRoomRemoved],
  ['ibsoft:internal-chat:member-removed', onRealtimeRoomRemoved],
];

const removeRealtimeListeners = () => {
  realtimeEventHandlers.forEach(([eventName, handler]) => {
    window.removeEventListener(eventName, handler);
  });
};

const addRealtimeListeners = () => {
  removeRealtimeListeners();
  realtimeEventHandlers.forEach(([eventName, handler]) => {
    window.addEventListener(eventName, handler);
  });
};

const messageBubbleClasses = message =>
  isOwnMessage(message)
    ? 'right-bubble bg-n-solid-blue text-n-slate-12 ltr:rounded-br-sm rtl:rounded-bl-sm'
    : 'left-bubble bg-n-slate-4 text-n-slate-12 ltr:rounded-bl-sm rtl:rounded-br-sm';

const messageMetaClasses = message =>
  isOwnMessage(message) ? 'justify-end' : 'justify-start';

const senderNameColorClasses = [
  'text-n-blue-11',
  'text-n-teal-11',
  'text-n-amber-11',
  'text-n-ruby-11',
];

const senderNameClasses = sender => {
  const senderId = Number(sender?.id) || 0;
  return senderNameColorClasses[
    Math.abs(senderId) % senderNameColorClasses.length
  ];
};

const shouldShowSenderName = (message, index) => {
  if (selectedRoom.value?.room_type !== 'room') return false;
  if (isOwnMessage(message)) return false;
  if (!agentDisplayName(message.sender)) return false;

  const previousMessage = messages.value[index - 1];
  return (
    previousMessage?.sender?.id !== message.sender?.id ||
    !isSameLocalDate(previousMessage?.created_at, message.created_at)
  );
};

const formattedMessageContent = message => {
  if (!message?.content) return '';

  return new MessageFormatter(message.content).formattedMessage;
};

const attachmentIcon = attachment => {
  if (attachment.file_type === 'audio') return 'i-lucide-volume-2';
  if (attachment.file_type === 'video') return 'i-lucide-film';
  if (attachment.file_type === 'image') return 'i-lucide-image';
  return 'i-lucide-paperclip';
};

const absoluteAttachmentUrl = url => {
  if (!url) return '';

  try {
    return new URL(attachmentUrl(url), window.location.origin).toString();
  } catch {
    return url;
  }
};

const audioChipAttachment = attachment => ({
  id: attachment.id,
  dataUrl: absoluteAttachmentUrl(attachmentSourceUrl(attachment)),
  fileType: attachment.file_type,
  extension: attachment.file_name?.split('.').pop() || '',
  transcribedText: attachment.transcribed_text,
});

const downloadAttachment = async attachment => {
  const objectUrl = await fetchAttachmentObjectUrl(attachment);
  if (!objectUrl) return;

  const link = document.createElement('a');
  link.href = objectUrl;
  link.download = attachment.file_name || '';
  link.rel = 'noopener noreferrer';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
};

const deactivateCurrentRoom = () => {
  nextRoomSelectionToken();
  selectedRoomId.value = null;
  clearActiveInternalChatRoom();
  store.dispatch('ibsoftInternalChat/clearActiveRoom');
};

onMounted(async () => {
  await Promise.all([fetchAgents(), fetchRooms()]);
  addRealtimeListeners();
});

watch(
  selectedRoomId,
  roomId => {
    setActiveInternalChatRoom(roomId);
    store.dispatch('ibsoftInternalChat/setActiveRoom', roomId);
  },
  { immediate: true }
);

onBeforeRouteLeave(() => {
  deactivateCurrentRoom();
});

onBeforeUnmount(() => {
  deactivateCurrentRoom();
  revokeAttachmentObjectUrls();
  if (pinMessagesToBottomTimer) clearTimeout(pinMessagesToBottomTimer);
  removeRealtimeListeners();
});

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    deactivateCurrentRoom();
    revokeAttachmentObjectUrls();
    removeRealtimeListeners();
  });
}
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full overflow-hidden bg-n-background max-md:flex-col"
  >
    <aside
      class="conversations-list-wrap relative flex w-[340px] flex-shrink-0 flex-col border-r border-n-weak bg-n-surface-1 2xl:w-[412px] max-md:h-72 max-md:w-full max-md:min-w-0 max-md:border-b max-md:border-r-0"
    >
      <header class="grid gap-3 border-b border-n-weak px-4 py-3">
        <div class="flex items-center justify-between gap-3">
          <div class="min-w-0">
            <h1 class="m-0 truncate text-base font-semibold text-n-slate-12">
              {{ t('IBSOFT_INTERNAL_CHAT.HEADER.TITLE') }}
            </h1>
          </div>
          <div
            v-on-click-outside="closeCreateMenu"
            class="relative flex items-center"
          >
            <Button
              icon="i-lucide-plus"
              color="blue"
              size="sm"
              :title="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CREATE_MENU')"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CREATE_MENU')"
              @click="toggleCreateMenu"
            />
            <DropdownMenu
              v-if="isCreateMenuOpen"
              :menu-items="createMenuItems"
              class="top-full mt-1 w-52 ltr:right-0 rtl:left-0"
              @action="onCreateMenuAction"
            />
          </div>
        </div>

        <Input
          v-model="roomSearchQuery"
          size="sm"
          custom-input-class="!pl-9"
          :placeholder="t('IBSOFT_INTERNAL_CHAT.ROOMS.SEARCH_PLACEHOLDER')"
        >
          <template #prefix>
            <span
              class="pointer-events-none absolute left-3 top-2 z-10 i-lucide-search size-4 text-n-slate-10"
            />
          </template>
        </Input>

        <div class="grid grid-cols-3 gap-1 rounded-lg bg-n-alpha-2 p-1">
          <button
            type="button"
            class="h-7 rounded-md text-xs font-medium text-n-slate-11"
            :class="{
              'bg-n-background text-n-slate-12 shadow-sm': roomFilter === 'all',
            }"
            @click="roomFilter = 'all'"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.FILTERS.ALL') }}
          </button>
          <button
            type="button"
            class="h-7 rounded-md text-xs font-medium text-n-slate-11"
            :class="{
              'bg-n-background text-n-slate-12 shadow-sm':
                roomFilter === 'room',
            }"
            @click="roomFilter = 'room'"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.FILTERS.ROOMS') }}
          </button>
          <button
            type="button"
            class="h-7 rounded-md text-xs font-medium text-n-slate-11"
            :class="{
              'bg-n-background text-n-slate-12 shadow-sm':
                roomFilter === 'direct',
            }"
            @click="roomFilter = 'direct'"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.FILTERS.DIRECT') }}
          </button>
        </div>
      </header>

      <section
        class="conversations-list flex-1 min-h-0 overflow-y-auto px-2 py-2"
      >
        <div v-if="isLoadingRooms" class="px-3 py-4 text-sm text-n-slate-11">
          {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.LOADING') }}
        </div>

        <div
          v-else-if="!filteredRooms.length"
          class="grid h-full place-content-center px-6 text-center text-sm text-n-slate-11"
        >
          {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.EMPTY_LIST') }}
        </div>

        <TransitionGroup
          v-else
          name="internal-chat-room-list"
          tag="div"
          class="grid gap-1"
        >
          <button
            v-for="room in filteredRooms"
            :key="room.id"
            type="button"
            class="flex w-full min-w-0 items-center gap-3 overflow-hidden rounded-lg px-3 py-2.5 text-left transition-colors hover:bg-n-alpha-2"
            :class="{
              'ibsoft-internal-chat-room--active': room.id === selectedRoomId,
              'bg-n-alpha-2': room.id === selectedRoomId,
              'bg-n-alpha-1 dark:bg-n-solid-2':
                room.id !== selectedRoomId && hasUnreadRoomMessages(room),
            }"
            @click="selectRoom(room)"
          >
            <Avatar
              v-if="isDirectRoom(room)"
              :name="roomDisplayName(room)"
              :src="roomAvatarSrc(room)"
              :status="roomAvailabilityStatus(room)"
              :size="40"
              rounded-full
            />
            <span
              v-else
              class="grid size-9 flex-shrink-0 place-content-center overflow-hidden rounded-full bg-n-alpha-2 text-n-slate-11"
            >
              <img
                v-if="roomCoverImageSrc(room)"
                :src="roomCoverImageSrc(room)"
                :alt="roomDisplayName(room)"
                class="size-full object-cover"
              />
              <span v-else :class="roomIcon(room)" />
            </span>
            <span class="block min-w-0 flex-1 overflow-hidden">
              <span class="flex min-w-0 items-center justify-between gap-2">
                <span
                  class="ibsoft-internal-chat-room__name min-w-0 flex-1 truncate text-sm font-medium text-n-slate-12"
                >
                  {{ roomDisplayName(room) }}
                </span>
                <time
                  class="flex-shrink-0 text-xs"
                  :class="
                    hasUnreadRoomMessages(room)
                      ? 'font-medium text-n-slate-12'
                      : 'text-n-slate-10'
                  "
                >
                  {{
                    formatTime(room.last_message?.created_at || room.updated_at)
                  }}
                </time>
              </span>
              <span
                class="mt-0.5 flex min-w-0 items-center gap-2 overflow-hidden"
              >
                <span
                  class="ibsoft-internal-chat-room__preview block min-w-0 max-w-full flex-1 truncate text-xs"
                  :class="
                    hasUnreadRoomMessages(room)
                      ? 'font-medium text-n-slate-12'
                      : 'text-n-slate-11'
                  "
                >
                  {{ roomPreview(room) }}
                </span>
                <UnreadBadge
                  v-if="hasUnreadRoomMessages(room)"
                  :count="roomUnreadCount(room)"
                />
              </span>
            </span>
          </button>
        </TransitionGroup>
      </section>
    </aside>

    <section
      ref="chatPanel"
      class="flex min-w-0 flex-1 flex-col bg-n-surface-1"
    >
      <header
        v-if="selectedRoom"
        ref="chatHeader"
        class="flex min-h-[4.5rem] items-center justify-between gap-4 border-b border-n-weak bg-n-background px-5 py-3"
      >
        <div class="flex min-w-0 items-center gap-3">
          <Avatar
            v-if="isDirectRoom(selectedRoom)"
            :name="roomDisplayName(selectedRoom)"
            :src="roomAvatarSrc(selectedRoom)"
            :status="roomAvailabilityStatus(selectedRoom)"
            :size="40"
            rounded-full
          />
          <span
            v-else
            class="grid size-10 flex-shrink-0 place-content-center overflow-hidden rounded-full bg-n-alpha-2 text-n-slate-11"
          >
            <img
              v-if="roomCoverImageSrc(selectedRoom)"
              :src="roomCoverImageSrc(selectedRoom)"
              :alt="roomDisplayName(selectedRoom)"
              class="size-full object-cover"
            />
            <span v-else :class="roomIcon(selectedRoom)" />
          </span>
          <div class="min-w-0">
            <h2 class="m-0 truncate text-base font-semibold text-n-slate-12">
              {{ roomDisplayName(selectedRoom) }}
            </h2>
            <p
              v-if="selectedRoom.room_type === 'room'"
              class="m-0 truncate text-xs text-n-slate-11"
            >
              {{ roomMembersLabel }}
            </p>
          </div>
        </div>
        <div
          v-if="selectedRoom.room_type === 'room'"
          class="flex items-center gap-2"
        >
          <div class="hidden max-w-[16rem] flex-wrap justify-end gap-1 md:flex">
            <Avatar
              v-for="member in selectedRoomMembers.slice(0, 6)"
              :key="member.id"
              :name="agentDisplayName(member)"
              :src="agentAvatarSrc(member)"
              :status="agentAvailabilityStatus(member)"
              :size="24"
              rounded-full
            />
          </div>
          <Button
            icon="i-lucide-settings-2"
            color="slate"
            size="sm"
            :title="t('IBSOFT_INTERNAL_CHAT.ACTIONS.EDIT_ROOM')"
            :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.EDIT_ROOM')"
            @click="openEditRoomModal"
          />
        </div>
        <div v-else-if="canDestroySelectedRoom" class="flex items-center gap-2">
          <Button
            icon="i-lucide-trash-2"
            color="ruby"
            size="sm"
            variant="ghost"
            :title="deleteSelectedChatLabel"
            :aria-label="deleteSelectedChatLabel"
            @click="openDeleteRoomConfirm"
          />
        </div>
      </header>

      <div
        v-if="errorMessage"
        ref="errorPanel"
        class="mx-5 mt-3 rounded-lg border border-n-ruby-8 bg-n-ruby-9/10 px-3 py-2 text-sm text-n-ruby-11"
      >
        {{ errorMessage }}
      </div>

      <section
        v-if="selectedRoom"
        ref="messagesPanel"
        class="conversation-panel relative m-0 flex h-full min-h-0 flex-shrink flex-grow basis-px flex-col overflow-y-auto bg-n-surface-1 pb-4"
        @scroll="handleMessagesScroll"
      >
        <div v-if="isLoadingMessages" class="px-4 py-5 text-sm text-n-slate-11">
          {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.LOADING') }}
        </div>
        <div
          v-else-if="!messages.length"
          class="ibsoft-internal-chat-empty-state flex h-full flex-col items-center justify-center text-center text-sm text-n-slate-11"
        >
          {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.EMPTY') }}
        </div>
        <div
          v-else
          class="flex min-h-0 w-full flex-1 flex-col bg-n-surface-1 px-4"
        >
          <div
            v-if="isLoadingOlderMessages"
            class="flex justify-center py-2 text-xs text-n-slate-11"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.LOADING_OLDER') }}
          </div>
          <div
            v-for="group in messageDateGroups"
            :key="group.key"
            class="flex w-full flex-col first:mt-auto"
          >
            <div
              class="my-4 flex items-center gap-3 text-center text-xs font-medium text-n-slate-11"
            >
              <span class="h-px flex-1 bg-n-weak" />
              <span class="rounded-full bg-n-alpha-2 px-3 py-1 text-n-slate-11">
                {{ group.label }}
              </span>
              <span class="h-px flex-1 bg-n-weak" />
            </div>

            <article
              v-for="{ message, index } in group.messages"
              :key="message.id"
              class="message-bubble-container mb-2 flex w-full gap-2"
              :class="{ 'justify-end': isOwnMessage(message) }"
            >
              <Avatar
                v-if="!isOwnMessage(message)"
                :name="agentDisplayName(message.sender)"
                :src="agentAvatarSrc(message.sender)"
                :status="agentAvailabilityStatus(message.sender)"
                :size="24"
                class="mt-auto"
                rounded-full
              />
              <div
                class="grid max-w-lg min-w-0 gap-1"
                :class="
                  isOwnMessage(message)
                    ? 'justify-items-end ltr:ml-8 rtl:mr-8'
                    : 'justify-items-start ltr:mr-8 rtl:ml-8'
                "
              >
                <div
                  class="max-w-full rounded-xl px-4 py-3 text-sm"
                  :class="messageBubbleClasses(message)"
                  data-bubble-name="text"
                >
                  <div
                    v-if="shouldShowSenderName(message, index)"
                    class="mb-1 max-w-full truncate text-start text-xs font-semibold leading-4"
                    :class="senderNameClasses(message.sender)"
                  >
                    {{ agentDisplayName(message.sender) }}
                  </div>
                  <span
                    v-if="message.content"
                    v-dompurify-html="formattedMessageContent(message)"
                    class="prose prose-bubble"
                  />
                  <div
                    v-if="message.attachments?.length"
                    class="mt-3 flex flex-col gap-2"
                  >
                    <template
                      v-for="attachment in message.attachments"
                      :key="attachment.id"
                    >
                      <button
                        v-if="attachment.file_type === 'image'"
                        type="button"
                        class="skip-context-menu block max-w-full cursor-pointer border-0 bg-transparent p-0 text-left"
                        :aria-label="
                          t('IBSOFT_INTERNAL_CHAT.ACTIONS.PREVIEW_IMAGE')
                        "
                        @click="openMediaPreview(attachment, message)"
                      >
                        <img
                          v-if="attachmentPreviewUrl(attachment)"
                          :src="attachmentPreviewUrl(attachment)"
                          :alt="attachment.file_name"
                          class="block max-h-52 max-w-full rounded-lg object-contain"
                          @load="keepMessagesPinnedToBottom"
                        />
                        <span
                          v-else
                          class="grid size-24 place-content-center rounded-lg bg-n-alpha-2 text-n-slate-11"
                        >
                          <span class="i-lucide-image size-6" />
                        </span>
                      </button>
                      <div
                        v-else-if="attachment.file_type === 'audio'"
                        class="w-80 max-w-full"
                      >
                        <InternalChatAudioChip
                          :attachment="audioChipAttachment(attachment)"
                          :load-source="
                            () => fetchAttachmentObjectUrl(attachment)
                          "
                          class="p-2 text-n-slate-12 skip-context-menu"
                        />
                      </div>
                      <button
                        v-else-if="attachment.file_type === 'video'"
                        type="button"
                        class="skip-context-menu group relative block aspect-video w-64 max-w-full cursor-pointer overflow-hidden rounded-lg border-0 bg-n-alpha-2 p-0 text-left"
                        :aria-label="
                          t('IBSOFT_INTERNAL_CHAT.ACTIONS.PREVIEW_VIDEO')
                        "
                        @click="openMediaPreview(attachment, message)"
                      >
                        <img
                          v-if="attachmentPreviewUrl(attachment)"
                          :src="attachmentPreviewUrl(attachment)"
                          :alt="attachment.file_name"
                          class="size-full object-cover"
                          @load="keepMessagesPinnedToBottom"
                        />
                        <span
                          v-else
                          class="grid size-full place-content-center text-n-slate-11"
                        >
                          <span class="i-lucide-film size-8" />
                        </span>
                        <span
                          class="absolute inset-0 grid place-content-center bg-n-alpha-black2 text-n-slate-12 opacity-90 transition-opacity group-hover:opacity-100"
                        >
                          <span
                            class="i-teenyicons-play-small-solid size-10 rounded-full bg-n-slate-1/70 shadow-sm"
                          />
                        </span>
                      </button>
                      <button
                        v-else
                        type="button"
                        class="flex min-w-0 items-center gap-2 rounded-lg border-0 bg-n-alpha-3 px-3 py-2 text-left text-sm text-n-slate-12"
                        @click="downloadAttachment(attachment)"
                      >
                        <span
                          class="size-4"
                          :class="attachmentIcon(attachment)"
                        />
                        <span class="min-w-0 truncate">
                          {{ attachment.file_name }}
                        </span>
                      </button>
                    </template>
                  </div>
                  <div
                    class="mt-2 flex items-center gap-1.5 text-xs text-n-slate-11"
                    :class="messageMetaClasses(message)"
                  >
                    <time>
                      {{ formatInternalMessageTime(message.created_at) }}
                    </time>
                  </div>
                </div>
              </div>
              <Avatar
                v-if="isOwnMessage(message)"
                :name="agentDisplayName(currentUser)"
                :src="agentAvatarSrc(currentUser)"
                :status="agentAvailabilityStatus(currentUser)"
                :size="24"
                class="mt-auto"
                rounded-full
              />
            </article>
          </div>
          <div aria-hidden="true" class="h-4 shrink-0" />
        </div>
      </section>

      <section
        v-else
        class="ibsoft-internal-chat-select-empty-state flex flex-1 flex-col items-center justify-center px-5 text-center text-sm text-n-slate-11"
      >
        {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.SELECT_CHAT') }}
      </section>

      <div v-if="selectedRoom" class="relative flex flex-col bg-n-surface-1">
        <div class="w-full">
          <div
            v-if="!canPostSelectedRoom"
            class="mx-2 mb-2 rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-11"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.READ_ONLY') }}
          </div>
          <ResizableEditorWrapper
            v-else
            ref="resizableEditorWrapper"
            :container-height="composerContainerHeight"
            :default-height="80"
            :min-height="64"
          >
            <InternalChatComposer
              v-model="composerText"
              v-model:attachments="selectedAttachments"
              :room-id="selectedRoom.id"
              :can-send="canSendMessage"
              :disabled="!canPostSelectedRoom"
              :is-sending="isSendingMessage"
              @send="sendMessage"
              @toggle-editor-size="toggleComposerHeight"
            />
          </ResizableEditorWrapper>
        </div>
      </div>
    </section>

    <MediaPreviewModal
      v-if="isMediaPreviewOpen && selectedMediaAttachment"
      v-model:show="isMediaPreviewOpen"
      :attachment="selectedMediaAttachment"
      :all-attachments="mediaGalleryAttachments"
      auto-play
      @close="closeMediaPreview"
    />

    <div
      v-if="isCreateRoomModalOpen"
      class="fixed inset-0 z-50 grid place-items-center bg-n-alpha-black1 px-4"
    >
      <section
        class="grid w-full max-w-lg gap-4 rounded-lg border border-n-weak bg-n-background p-5 shadow-xl"
      >
        <header class="flex items-center justify-between gap-3">
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.NEW_ROOM') }}
          </h2>
          <Button
            icon="i-lucide-x"
            color="slate"
            size="sm"
            :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CLOSE')"
            @click="closeCreateRoomModal"
          />
        </header>
        <Input
          v-model="createRoomName"
          size="md"
          :label="t('IBSOFT_INTERNAL_CHAT.ROOMS.NAME')"
          :placeholder="t('IBSOFT_INTERNAL_CHAT.ROOMS.NAME_PLACEHOLDER')"
          autofocus
          @enter="createRoom"
        />
        <div class="grid gap-2">
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.MEMBERS') }}
          </p>
          <div
            class="grid max-h-64 gap-1 overflow-y-auto rounded-lg border border-n-weak p-2"
          >
            <p
              v-if="!availableAgents.length"
              class="m-0 px-2 py-4 text-center text-sm text-n-slate-11"
            >
              {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.NO_AGENTS') }}
            </p>
            <template v-else>
              <label
                v-for="agent in availableAgents"
                :key="agent.id"
                class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm text-n-slate-12 hover:bg-n-alpha-2"
              >
                <input
                  v-model="createMemberIds"
                  type="checkbox"
                  class="m-0 size-4 accent-n-brand"
                  :value="agent.id"
                />
                <Avatar
                  :name="agent.available_name || agent.name"
                  :src="agent.thumbnail"
                  :status="agent.availability_status"
                  :size="24"
                  rounded-full
                />
                <span class="min-w-0 truncate">
                  {{ agent.available_name || agent.name }}
                </span>
              </label>
            </template>
          </div>
        </div>
        <footer class="flex justify-end gap-2">
          <Button
            :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CANCEL')"
            color="slate"
            variant="ghost"
            @click="closeCreateRoomModal"
          />
          <Button
            :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CREATE_ROOM')"
            icon="i-lucide-plus"
            color="blue"
            :is-loading="isSavingRoom"
            :disabled="!createRoomName.trim()"
            @click="createRoom"
          />
        </footer>
      </section>
    </div>

    <div
      v-if="isDirectChatModalOpen"
      class="fixed inset-0 z-50 grid place-items-center bg-n-alpha-black1 px-4"
    >
      <section
        class="grid w-full max-w-md gap-4 rounded-lg border border-n-weak bg-n-background p-5 shadow-xl"
      >
        <header class="flex items-center justify-between gap-3">
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.DIRECT.NEW') }}
          </h2>
          <Button
            icon="i-lucide-x"
            color="slate"
            size="sm"
            :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CLOSE')"
            @click="closeDirectChatModal"
          />
        </header>
        <Input
          v-model="directSearchQuery"
          size="md"
          :placeholder="t('IBSOFT_INTERNAL_CHAT.DIRECT.SEARCH_PLACEHOLDER')"
          autofocus
        />
        <div class="grid max-h-80 gap-1 overflow-y-auto">
          <p
            v-if="!filteredAgents.length"
            class="m-0 px-2 py-4 text-center text-sm text-n-slate-11"
          >
            {{ t('IBSOFT_INTERNAL_CHAT.DIRECT.EMPTY') }}
          </p>
          <template v-else>
            <button
              v-for="agent in filteredAgents"
              :key="agent.id"
              type="button"
              class="flex items-center gap-3 rounded-lg px-2 py-2 text-left text-sm text-n-slate-12 hover:bg-n-alpha-2"
              @click="startDirectChat(agent)"
            >
              <Avatar
                :name="agent.available_name || agent.name"
                :src="agent.thumbnail"
                :status="agent.availability_status"
                :size="32"
                rounded-full
              />
              <span class="min-w-0 flex-1 truncate">
                {{ agent.available_name || agent.name }}
              </span>
              <span class="i-lucide-message-circle size-4 text-n-slate-10" />
            </button>
          </template>
        </div>
      </section>
    </div>

    <div
      v-if="isEditRoomModalOpen"
      class="fixed inset-0 z-50 grid place-items-center bg-n-alpha-black1 px-4"
    >
      <section
        class="grid w-full max-w-lg gap-4 rounded-lg border border-n-weak bg-n-background p-5 shadow-xl"
      >
        <header class="flex items-center justify-between gap-3">
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.EDIT_ROOM') }}
          </h2>
          <Button
            icon="i-lucide-x"
            color="slate"
            size="sm"
            :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CLOSE')"
            @click="closeEditRoomModal"
          />
        </header>
        <Input
          v-model="editRoomName"
          size="md"
          :label="t('IBSOFT_INTERNAL_CHAT.ROOMS.NAME')"
          :placeholder="t('IBSOFT_INTERNAL_CHAT.ROOMS.NAME_PLACEHOLDER')"
          :disabled="!canManageSelectedRoomMembers"
          autofocus
          @enter="updateRoom"
        />
        <div class="grid gap-2">
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.COVER_IMAGE') }}
          </p>
          <div class="flex items-center gap-3">
            <span
              class="grid size-14 flex-shrink-0 place-content-center overflow-hidden rounded-lg bg-n-alpha-2 text-n-slate-11"
            >
              <img
                v-if="editCoverPreviewUrl"
                :src="editCoverPreviewUrl"
                :alt="editRoomName"
                class="size-full object-cover"
              />
              <span v-else class="i-lucide-users-round size-5" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="m-0 text-sm text-n-slate-11">
                {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.COVER_IMAGE_HELP') }}
              </p>
              <input
                ref="coverImageInput"
                type="file"
                accept="image/png,image/jpeg,image/jpg,image/gif,image/webp"
                class="hidden"
                @change="onCoverImageSelected"
              />
            </div>
            <Button
              :label="
                editCoverPreviewUrl
                  ? t('IBSOFT_INTERNAL_CHAT.ACTIONS.CHANGE_COVER')
                  : t('IBSOFT_INTERNAL_CHAT.ACTIONS.CHOOSE_COVER')
              "
              icon="i-lucide-image-plus"
              color="slate"
              variant="outline"
              @click="coverImageInput?.click()"
            />
          </div>
          <div
            v-if="coverCropImageUrl"
            class="grid gap-3 rounded-lg border border-n-weak bg-n-alpha-2 p-3"
          >
            <p class="m-0 text-sm font-medium text-n-slate-12">
              {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.CROP_COVER') }}
            </p>
            <div
              class="mx-auto grid size-44 place-content-center overflow-hidden rounded-lg bg-n-background"
            >
              <img
                :src="coverCropImageUrl"
                :alt="t('IBSOFT_INTERNAL_CHAT.ROOMS.CROP_COVER')"
                class="size-44 object-cover"
                :style="{ transform: `scale(${coverCropZoom})` }"
              />
            </div>
            <label class="grid gap-1 text-sm text-n-slate-11">
              {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.COVER_ZOOM') }}
              <input
                v-model="coverCropZoom"
                type="range"
                min="1"
                max="3"
                step="0.05"
                class="accent-n-brand"
              />
            </label>
            <div class="flex justify-end gap-2">
              <Button
                :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CANCEL_CROP')"
                color="slate"
                variant="ghost"
                @click="clearCoverCrop"
              />
              <Button
                :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.APPLY_CROP')"
                icon="i-lucide-crop"
                color="blue"
                @click="applyCoverCrop"
              />
            </div>
          </div>
        </div>
        <div class="grid gap-2">
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.CURRENT_MEMBERS') }}
          </p>
          <div
            class="grid max-h-64 gap-1 overflow-y-auto rounded-lg border border-n-weak p-2"
          >
            <div
              v-for="member in selectedRoomMembers"
              :key="member.id"
              class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm text-n-slate-12"
            >
              <Avatar
                :name="agentDisplayName(member)"
                :src="agentAvatarSrc(member)"
                :status="agentAvailabilityStatus(member)"
                :size="24"
                rounded-full
              />
              <span class="min-w-0 flex-1 truncate">
                {{ agentDisplayName(member) }}
              </span>
              <span
                v-if="member.is_creator"
                class="rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs text-n-slate-10"
              >
                {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.OWNER') }}
              </span>
              <Button
                v-if="canManageSelectedRoomMembers && !member.is_creator"
                icon="i-lucide-user-minus"
                color="ruby"
                size="xs"
                variant="ghost"
                :title="t('IBSOFT_INTERNAL_CHAT.ACTIONS.REMOVE_MEMBER')"
                :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.REMOVE_MEMBER')"
                @click="removeRoomMember(member)"
              />
            </div>
          </div>
        </div>
        <div v-if="canManageSelectedRoomMembers" class="grid gap-2">
          <p class="m-0 text-sm font-medium text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.ADD_MEMBERS') }}
          </p>
          <div
            class="grid max-h-64 gap-1 overflow-y-auto rounded-lg border border-n-weak p-2"
          >
            <p
              v-if="!roomMemberCandidates.length"
              class="m-0 px-2 py-4 text-center text-sm text-n-slate-11"
            >
              {{ t('IBSOFT_INTERNAL_CHAT.ROOMS.NO_AVAILABLE_AGENTS') }}
            </p>
            <template v-else>
              <label
                v-for="agent in roomMemberCandidates"
                :key="agent.id"
                class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm text-n-slate-12"
              >
                <input
                  v-model="editMemberIds"
                  type="checkbox"
                  class="m-0 size-4 accent-n-brand"
                  :value="agent.id"
                />
                <Avatar
                  :name="agent.available_name || agent.name"
                  :src="agent.thumbnail"
                  :status="agent.availability_status"
                  :size="24"
                  rounded-full
                />
                <span class="min-w-0 flex-1 truncate">
                  {{ agent.available_name || agent.name }}
                </span>
              </label>
            </template>
          </div>
        </div>
        <footer class="flex justify-between gap-2">
          <div>
            <Button
              v-if="canDestroySelectedRoom"
              :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.DELETE_ROOM')"
              icon="i-lucide-trash-2"
              color="ruby"
              variant="ghost"
              :is-loading="isSavingRoom"
              @click="openDeleteRoomConfirm"
            />
          </div>
          <div class="flex justify-end gap-2">
            <Button
              :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CANCEL')"
              color="slate"
              variant="ghost"
              @click="closeEditRoomModal"
            />
            <Button
              :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.SAVE')"
              icon="i-lucide-check"
              color="blue"
              :is-loading="isSavingRoom"
              :disabled="!editRoomName.trim()"
              @click="updateRoom"
            />
          </div>
        </footer>
      </section>
    </div>

    <div
      v-if="isDeleteRoomConfirmOpen"
      class="fixed inset-0 z-[60] grid place-items-center bg-n-alpha-black1 px-4"
    >
      <section
        class="grid w-full max-w-md gap-4 rounded-lg border border-n-weak bg-n-background p-5 shadow-xl"
      >
        <header class="flex items-center justify-between gap-3">
          <h2 class="m-0 text-base font-semibold text-n-slate-12">
            {{ deleteSelectedChatLabel }}
          </h2>
          <Button
            icon="i-lucide-x"
            color="slate"
            size="sm"
            :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CLOSE')"
            @click="closeDeleteRoomConfirm"
          />
        </header>
        <p class="m-0 text-sm leading-5 text-n-slate-11">
          {{ deleteSelectedChatConfirm }}
        </p>
        <footer class="flex justify-end gap-2">
          <Button
            :label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CANCEL')"
            color="slate"
            variant="ghost"
            @click="closeDeleteRoomConfirm"
          />
          <Button
            :label="deleteSelectedChatLabel"
            icon="i-lucide-trash-2"
            color="ruby"
            :is-loading="isSavingRoom"
            @click="deleteRoom"
          />
        </footer>
      </section>
    </div>
  </main>
</template>

<style scoped>
.internal-chat-room-list-move {
  transition: transform 180ms ease;
}
</style>
