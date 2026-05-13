<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useImageZoom } from 'dashboard/composables/useImageZoom';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import InternalChatAPI from '../api/internalChat';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  allAttachments: {
    type: Array,
    required: true,
  },
  autoPlay: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });

const { t } = useI18n();

const imageRef = ref(null);
const activeIndex = ref(0);
const isDownloading = ref(false);
const isLoadingMedia = ref(true);
const loadProgress = ref(0);
const mediaLoadFailed = ref(false);
const activeMediaUrl = ref('');
const protectedMediaObjectUrls = ref({});
const protectedMediaObjectUrlRequests = new Map();
let mediaLoadRequestId = 0;
let protectedMediaObjectUrlGeneration = 0;

const {
  imageWrapperStyle,
  imageStyle,
  onRotate,
  activeImageRotation,
  onZoom,
  onDoubleClickZoomImage,
  onWheelImageZoom,
  onMouseMove,
  onMouseLeave,
  resetZoomAndRotation,
} = useImageZoom(imageRef);

const attachmentIdentifier = attachment =>
  attachment?.id || attachment?.message_id || attachment?.data_url;

const findAttachmentIndex = attachment => {
  const targetId = attachmentIdentifier(attachment);
  const index = props.allAttachments.findIndex(
    item => attachmentIdentifier(item) === targetId
  );

  return index === -1 ? 0 : index;
};

const activeAttachment = computed(
  () => props.allAttachments[activeIndex.value] || props.attachment
);

const activeAttachmentId = computed(() =>
  attachmentIdentifier(activeAttachment.value)
);

const isImage = computed(() => activeAttachment.value?.file_type === 'image');

const isVideo = computed(() => activeAttachment.value?.file_type === 'video');

const hasMoreThanOneAttachment = computed(
  () => props.allAttachments.length > 1
);

const canGoPrevious = computed(() => activeIndex.value > 0);

const canGoNext = computed(
  () => activeIndex.value < props.allAttachments.length - 1
);

const senderDetails = computed(() => {
  const { sender } = activeAttachment.value || {};

  return {
    name: sender?.name || sender?.available_name || '',
    avatar: sender?.thumbnail || sender?.avatar_url || '',
  };
});

const fileName = computed(() => activeAttachment.value?.file_name || '');

const progressWidth = computed(() => {
  if (!loadProgress.value) return '40%';

  return `${Math.max(8, Math.round(loadProgress.value * 100))}%`;
});

const resetMediaLoadingState = () => {
  isLoadingMedia.value = true;
  loadProgress.value = 0;
  mediaLoadFailed.value = false;
  activeMediaUrl.value = '';
  resetZoomAndRotation();
};

const onMediaLoaded = () => {
  loadProgress.value = 1;
  isLoadingMedia.value = false;
};

const onMediaLoadError = () => {
  isLoadingMedia.value = false;
  mediaLoadFailed.value = true;
};

const onVideoProgress = event => {
  const video = event.target;
  const bufferedRanges = video?.buffered;
  const duration = video?.duration;
  if (!bufferedRanges?.length || !Number.isFinite(duration) || duration <= 0) {
    return;
  }

  loadProgress.value = Math.min(
    bufferedRanges.end(bufferedRanges.length - 1) / duration,
    1
  );
};

const isLocalMediaUrl = url =>
  url.startsWith('blob:') || url.startsWith('data:');

const sourceUrlForAttachment = attachment =>
  attachment?.source_url || attachment?.data_url || '';

const needsAuthenticatedFetch = url =>
  url.includes('/ibsoft/internal_chat/') || url.includes('/api/v1/accounts/');

const fetchProtectedMediaUrl = async url => {
  if (protectedMediaObjectUrls.value[url]) {
    return protectedMediaObjectUrls.value[url];
  }

  if (protectedMediaObjectUrlRequests.has(url)) {
    return protectedMediaObjectUrlRequests.get(url);
  }

  const generation = protectedMediaObjectUrlGeneration;
  const request = InternalChatAPI.attachment(url)
    .then(({ data }) => {
      const objectUrl = URL.createObjectURL(data);
      if (generation !== protectedMediaObjectUrlGeneration) {
        URL.revokeObjectURL(objectUrl);
        return '';
      }

      protectedMediaObjectUrls.value = {
        ...protectedMediaObjectUrls.value,
        [url]: objectUrl,
      };
      return objectUrl;
    })
    .catch(() => '')
    .finally(() => {
      protectedMediaObjectUrlRequests.delete(url);
    });

  protectedMediaObjectUrlRequests.set(url, request);
  return request;
};

const prepareActiveMediaUrl = async () => {
  mediaLoadRequestId += 1;
  const requestId = mediaLoadRequestId;
  resetMediaLoadingState();

  const sourceUrl = sourceUrlForAttachment(activeAttachment.value);
  if (!sourceUrl) {
    onMediaLoadError();
    return;
  }

  const mediaUrl =
    isLocalMediaUrl(sourceUrl) || !needsAuthenticatedFetch(sourceUrl)
      ? sourceUrl
      : await fetchProtectedMediaUrl(sourceUrl);

  if (requestId !== mediaLoadRequestId) return;
  if (!mediaUrl) {
    onMediaLoadError();
    return;
  }

  activeMediaUrl.value = mediaUrl;
};

const onClickDownload = async () => {
  try {
    isDownloading.value = true;
    const url =
      activeMediaUrl.value ||
      (await fetchProtectedMediaUrl(
        sourceUrlForAttachment(activeAttachment.value)
      ));
    if (!url) return;

    const link = document.createElement('a');
    link.href = url;
    link.download = fileName.value;
    link.rel = 'noopener noreferrer';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  } catch (error) {
    useAlert(t('IBSOFT_INTERNAL_CHAT.ERRORS.DOWNLOAD_ATTACHMENT'));
  } finally {
    isDownloading.value = false;
  }
};

const changeAttachment = nextIndex => {
  if (nextIndex < 0 || nextIndex >= props.allAttachments.length) return;

  activeIndex.value = nextIndex;
};

const onClose = () => {
  show.value = false;
  emit('close');
};

const onKeydown = event => {
  if (!show.value) return;

  if (event.key === 'Escape') onClose();
  if (event.key === 'ArrowLeft' && canGoPrevious.value) {
    changeAttachment(activeIndex.value - 1);
  }
  if (event.key === 'ArrowRight' && canGoNext.value) {
    changeAttachment(activeIndex.value + 1);
  }
};

watch(
  () => attachmentIdentifier(props.attachment),
  () => {
    activeIndex.value = findAttachmentIndex(props.attachment);
    prepareActiveMediaUrl();
  },
  { immediate: true }
);

watch(
  () => [
    activeAttachmentId.value,
    activeAttachment.value?.data_url,
    activeAttachment.value?.source_url,
  ],
  (newValue, previousValue) => {
    if (!previousValue || newValue.join(':') === previousValue.join(':')) {
      return;
    }

    prepareActiveMediaUrl();
  }
);

onMounted(() => {
  window.addEventListener('keydown', onKeydown);
});

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown);
  protectedMediaObjectUrlGeneration += 1;
  Object.values(protectedMediaObjectUrls.value).forEach(objectUrl => {
    URL.revokeObjectURL(objectUrl);
  });
  protectedMediaObjectUrlRequests.clear();
});
</script>

<template>
  <TeleportWithDirection to="body">
    <woot-modal
      v-model:show="show"
      full-width
      :show-close-button="false"
      :on-close="onClose"
    >
      <div
        class="flex h-[inherit] w-[inherit] select-none flex-col overflow-hidden bg-n-background"
        @click="onClose"
      >
        <div
          v-if="isLoadingMedia"
          class="absolute left-0 right-0 top-0 z-20 h-1 overflow-hidden bg-n-alpha-2"
        >
          <div
            class="h-full bg-n-brand transition-all duration-300"
            :class="{ 'internal-chat-media-progress': !loadProgress }"
            :style="{ width: progressWidth }"
          />
        </div>

        <header
          class="z-10 flex h-16 w-full items-center justify-between border-b border-n-weak bg-n-background px-6 py-2"
          @click.stop
        >
          <div class="flex min-w-[12rem] shrink-0 items-center">
            <Avatar
              v-if="senderDetails.avatar || senderDetails.name"
              :name="senderDetails.name"
              :src="senderDetails.avatar"
              :size="40"
              rounded-full
              class="shrink-0"
            />
            <div class="ml-2 min-w-0 overflow-hidden rtl:ml-0 rtl:mr-2">
              <h3 class="m-0 truncate text-base font-medium text-n-slate-12">
                {{ senderDetails.name }}
              </h3>
            </div>
          </div>

          <div
            class="mx-2 min-w-0 flex-1 truncate px-2 text-center text-sm font-medium text-n-slate-12"
          >
            {{ fileName }}
          </div>

          <div class="ml-2 flex shrink-0 items-center gap-2">
            <Button
              v-if="isImage"
              icon="i-lucide-zoom-in"
              color="slate"
              variant="ghost"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ZOOM_IN')"
              @click="onZoom(0.1)"
            />
            <Button
              v-if="isImage"
              icon="i-lucide-zoom-out"
              color="slate"
              variant="ghost"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ZOOM_OUT')"
              @click="onZoom(-0.1)"
            />
            <Button
              v-if="isImage"
              icon="i-lucide-rotate-ccw"
              color="slate"
              variant="ghost"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ROTATE_LEFT')"
              @click="onRotate('counter-clockwise')"
            />
            <Button
              v-if="isImage"
              icon="i-lucide-rotate-cw"
              color="slate"
              variant="ghost"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ROTATE_RIGHT')"
              @click="onRotate('clockwise')"
            />
            <Button
              icon="i-lucide-download"
              color="slate"
              variant="ghost"
              :is-loading="isDownloading"
              :disabled="isDownloading"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.DOWNLOAD')"
              @click="onClickDownload"
            />
            <Button
              icon="i-lucide-x"
              color="slate"
              variant="ghost"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.CLOSE')"
              @click="onClose"
            />
          </div>
        </header>

        <main class="flex h-full flex-1 items-stretch overflow-hidden">
          <div class="flex w-16 shrink-0 items-center justify-center">
            <Button
              v-if="hasMoreThanOneAttachment"
              icon="ltr:i-lucide-chevron-left rtl:i-lucide-chevron-right"
              color="blue"
              variant="faded"
              size="lg"
              :disabled="!canGoPrevious"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.PREVIOUS_MEDIA')"
              @click.stop="changeAttachment(activeIndex - 1)"
            />
          </div>

          <div
            class="relative flex flex-1 items-center justify-center overflow-hidden"
            @click.stop
          >
            <div
              v-if="mediaLoadFailed"
              class="rounded-lg bg-n-alpha-2 px-4 py-3 text-sm text-n-slate-11"
            >
              {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.MEDIA_UNAVAILABLE') }}
            </div>

            <div
              v-else-if="isImage && activeMediaUrl"
              :style="imageWrapperStyle"
              class="flex origin-center items-center justify-center"
              :class="{
                'h-[calc(100dvw-7rem)] w-[calc(100dvh-8rem)]':
                  activeImageRotation % 180 !== 0,
                'size-full': activeImageRotation % 180 === 0,
              }"
            >
              <img
                ref="imageRef"
                :key="activeAttachment.id"
                :src="activeMediaUrl"
                :alt="fileName"
                :style="imageStyle"
                class="max-h-full max-w-full select-none object-contain duration-100 ease-in-out"
                @load="onMediaLoaded"
                @error="onMediaLoadError"
                @dblclick.stop="onDoubleClickZoomImage"
                @wheel.prevent.stop="onWheelImageZoom"
                @mousemove="onMouseMove"
                @mouseleave="onMouseLeave"
              />
            </div>

            <video
              v-else-if="isVideo && activeMediaUrl"
              :key="activeAttachment.id"
              :src="activeMediaUrl"
              controls
              playsinline
              :autoplay="autoPlay"
              class="max-h-full max-w-full object-contain"
              @loadeddata="onMediaLoaded"
              @canplay="onMediaLoaded"
              @progress="onVideoProgress"
              @error="onMediaLoadError"
            />
          </div>

          <div class="flex w-16 shrink-0 items-center justify-center">
            <Button
              v-if="hasMoreThanOneAttachment"
              icon="ltr:i-lucide-chevron-right rtl:i-lucide-chevron-left"
              color="blue"
              variant="faded"
              size="lg"
              :disabled="!canGoNext"
              :aria-label="t('IBSOFT_INTERNAL_CHAT.ACTIONS.NEXT_MEDIA')"
              @click.stop="changeAttachment(activeIndex + 1)"
            />
          </div>
        </main>

        <footer
          class="z-10 flex h-12 items-center justify-center border-t border-n-weak"
        >
          <div
            class="rounded-md bg-n-slate-3 px-3 py-1 text-sm font-medium text-n-slate-12"
          >
            {{ `${activeIndex + 1} / ${allAttachments.length}` }}
          </div>
        </footer>
      </div>
    </woot-modal>
  </TeleportWithDirection>
</template>

<style scoped>
.internal-chat-media-progress {
  animation: internal-chat-media-progress 1s ease-in-out infinite;
}

@keyframes internal-chat-media-progress {
  0% {
    transform: translateX(-100%);
  }

  100% {
    transform: translateX(260%);
  }
}
</style>
