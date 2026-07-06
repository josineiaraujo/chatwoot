<script setup>
import {
  computed,
  getCurrentInstance,
  nextTick,
  onMounted,
  ref,
  useTemplateRef,
} from 'vue';
import Icon from 'next/icon/Icon.vue';
import { downloadFile } from '@chatwoot/utils';
import { useEmitter } from 'dashboard/composables/emitter';
import { emitter } from 'shared/helpers/mitt';
import { audioPlaybackUrl } from '../helpers/attachmentUrls';

const props = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
  loadSource: {
    type: Function,
    default: null,
  },
});

defineOptions({
  inheritAttrs: false,
});

const audioPlayer = useTemplateRef('audioPlayer');

const { uid } = getCurrentInstance();

const isPlaying = ref(false);
const isMuted = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackSpeed = ref(1);
const isLoadingSource = ref(false);
const loadedDataUrl = ref('');

const rawSourceUrl = computed(
  () => loadedDataUrl.value || props.attachment.dataUrl || ''
);

const sourceUrl = computed(() => audioPlaybackUrl(rawSourceUrl.value));

const playbackSpeedLabel = computed(() => `${playbackSpeed.value}x`);

const resolveStreamingDuration = () => {
  const el = audioPlayer.value;
  if (!el) return;

  const onTimeUpdate = () => {
    el.removeEventListener('timeupdate', onTimeUpdate);
    el.currentTime = 0;
    duration.value = el.duration;
  };

  el.addEventListener('timeupdate', onTimeUpdate);
  try {
    el.currentTime = Number.MAX_SAFE_INTEGER;
  } catch {
    el.removeEventListener('timeupdate', onTimeUpdate);
  }
};

const onLoadedMetadata = () => {
  const nextDuration = audioPlayer.value?.duration;
  if (!Number.isFinite(nextDuration)) {
    resolveStreamingDuration();
    return;
  }

  duration.value = nextDuration;
};

onMounted(() => {
  const nextDuration = audioPlayer.value?.duration;
  if (Number.isFinite(nextDuration)) duration.value = nextDuration;
  if (audioPlayer.value) audioPlayer.value.playbackRate = playbackSpeed.value;
});

useEmitter('pause_playing_audio', currentPlayingId => {
  if (currentPlayingId !== uid && isPlaying.value) {
    try {
      audioPlayer.value?.pause();
    } catch {
      // Ignore browser media state errors.
    }
    isPlaying.value = false;
  }
});

const formatTime = time => {
  if (!time || Number.isNaN(time)) return '00:00';

  const minutes = Math.floor(time / 60);
  const seconds = Math.floor(time % 60);
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

const playbackTimeLabel = computed(
  () => `${formatTime(currentTime.value)} / ${formatTime(duration.value)}`
);

const toggleMute = () => {
  if (!audioPlayer.value) return;

  audioPlayer.value.muted = !audioPlayer.value.muted;
  isMuted.value = audioPlayer.value.muted;
};

const onTimeUpdate = () => {
  currentTime.value = audioPlayer.value?.currentTime || 0;
};

const seek = event => {
  if (!audioPlayer.value) return;

  const time = Number(event.target.value);
  audioPlayer.value.currentTime = time;
  currentTime.value = time;
};

const ensureSource = async () => {
  if (sourceUrl.value) return true;
  if (!props.loadSource || isLoadingSource.value) return false;

  isLoadingSource.value = true;
  try {
    const nextSourceUrl = await props.loadSource();
    loadedDataUrl.value = nextSourceUrl || '';
    await nextTick();
    audioPlayer.value?.load();
    return Boolean(sourceUrl.value);
  } finally {
    isLoadingSource.value = false;
  }
};

const playOrPause = async () => {
  const hasSource = await ensureSource();
  if (!hasSource) return;
  if (!audioPlayer.value) return;

  if (isPlaying.value) {
    audioPlayer.value.pause();
    isPlaying.value = false;
    return;
  }

  emitter.emit('pause_playing_audio', uid);
  try {
    await audioPlayer.value.play();
    isPlaying.value = true;
  } catch {
    isPlaying.value = false;
  }
};

const onEnd = () => {
  isPlaying.value = false;
  currentTime.value = 0;
  playbackSpeed.value = 1;
  if (audioPlayer.value) audioPlayer.value.playbackRate = 1;
};

const changePlaybackSpeed = () => {
  if (!audioPlayer.value) return;

  const speeds = [1, 1.5, 2];
  const currentIndex = speeds.indexOf(playbackSpeed.value);
  const nextIndex = (currentIndex + 1) % speeds.length;
  playbackSpeed.value = speeds[nextIndex];
  audioPlayer.value.playbackRate = playbackSpeed.value;
};

const downloadAudio = async () => {
  const hasSource = await ensureSource();
  if (!hasSource) return;

  const { fileType, extension } = props.attachment;
  const dataUrl = rawSourceUrl.value;
  downloadFile({ url: dataUrl, type: fileType, extension });
};
</script>

<template>
  <audio
    ref="audioPlayer"
    controls
    class="hidden"
    playsinline
    @loadedmetadata="onLoadedMetadata"
    @timeupdate="onTimeUpdate"
    @ended="onEnd"
  >
    <source :src="sourceUrl" />
  </audio>
  <div
    v-bind="$attrs"
    class="rounded-xl w-full gap-2 p-1.5 bg-n-alpha-white flex flex-col items-center border border-n-container shadow-[0px_2px_8px_0px_rgba(94,94,94,0.06)]"
  >
    <div class="flex gap-1 w-full flex-1 items-center justify-start">
      <button type="button" class="p-0 border-0 size-8" @click="playOrPause">
        <Icon
          v-if="isLoadingSource"
          class="size-4 animate-spin"
          icon="i-lucide-loader-circle"
        />
        <Icon
          v-else-if="isPlaying"
          class="size-8"
          icon="i-teenyicons-pause-small-solid"
        />
        <Icon v-else class="size-8" icon="i-teenyicons-play-small-solid" />
      </button>
      <div class="tabular-nums text-xs">
        {{ playbackTimeLabel }}
      </div>
      <div class="flex-1 items-center flex px-2">
        <input
          type="range"
          min="0"
          :max="duration"
          :value="currentTime"
          class="w-full h-1 bg-n-slate-12/40 rounded-lg appearance-none cursor-pointer accent-current"
          @input="seek"
        />
      </div>
      <button
        type="button"
        class="border-0 w-10 h-6 grid place-content-center bg-n-alpha-2 hover:bg-alpha-3 rounded-2xl"
        @click="changePlaybackSpeed"
      >
        <span class="text-xs text-n-slate-11 font-medium">
          {{ playbackSpeedLabel }}
        </span>
      </button>
      <button
        type="button"
        class="p-0 border-0 size-8 grid place-content-center"
        @click="toggleMute"
      >
        <Icon v-if="isMuted" class="size-4" icon="i-lucide-volume-off" />
        <Icon v-else class="size-4" icon="i-lucide-volume-2" />
      </button>
      <button
        type="button"
        class="p-0 border-0 size-8 grid place-content-center"
        @click="downloadAudio"
      >
        <Icon class="size-4" icon="i-lucide-download" />
      </button>
    </div>
  </div>
</template>
