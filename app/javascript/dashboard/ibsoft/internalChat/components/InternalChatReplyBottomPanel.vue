<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import FileUpload from 'vue-upload-component';

import Button from 'dashboard/components-next/button/Button.vue';

import { ALLOWED_FILE_TYPES } from 'shared/constants/messages';

const props = defineProps({
  disabled: {
    type: Boolean,
    default: false,
  },
  isRecordingAudio: {
    type: Boolean,
    default: false,
  },
  isSendDisabled: {
    type: Boolean,
    default: false,
  },
  isSending: {
    type: Boolean,
    default: false,
  },
  recordingAudioDurationText: {
    type: String,
    default: '00:00',
  },
  recordingAudioState: {
    type: String,
    default: '',
  },
  sendButtonText: {
    type: String,
    default: '',
  },
});

const emit = defineEmits([
  'file-upload',
  'send',
  'toggle-audio-recorder',
  'toggle-audio-recorder-play-pause',
  'toggle-emoji-picker',
]);

const { t } = useI18n();
const uploadRef = ref(null);

const audioRecorderPlayStopIcon = computed(() => {
  switch (props.recordingAudioState) {
    case 'playing':
      return 'i-ph-pause';
    case 'paused':
    case 'stopped':
      return 'i-ph-play';
    default:
      return 'i-ph-stop';
  }
});
</script>

<template>
  <div class="flex justify-between p-3">
    <div class="left-wrap">
      <Button
        v-if="!disabled"
        v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.SHOW_EMOJI_PICKER')"
        icon="i-ph-smiley-sticker"
        slate
        faded
        sm
        @click="emit('toggle-emoji-picker')"
      />
      <FileUpload
        v-if="!disabled"
        ref="uploadRef"
        v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ATTACH')"
        input-id="ibsoftInternalChatAttachment"
        :size="4096 * 4096"
        :accept="ALLOWED_FILE_TYPES"
        multiple
        drop
        :drop-directory="false"
        @input-file="emit('file-upload', $event)"
      >
        <Button
          v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ATTACH')"
          icon="i-ph-paperclip"
          slate
          faded
          sm
        />
      </FileUpload>
      <Button
        v-if="!disabled"
        v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.RECORD_AUDIO')"
        :icon="!isRecordingAudio ? 'i-ph-microphone' : 'i-ph-microphone-slash'"
        slate
        faded
        sm
        @click="emit('toggle-audio-recorder')"
      />
      <Button
        v-if="!disabled && isRecordingAudio"
        v-tooltip.top-end="
          t('IBSOFT_INTERNAL_CHAT.ACTIONS.TOGGLE_RECORDED_AUDIO')
        "
        :icon="audioRecorderPlayStopIcon"
        slate
        faded
        sm
        :label="recordingAudioDurationText"
        @click="emit('toggle-audio-recorder-play-pause')"
      />
      <transition name="modal-fade">
        <div
          v-show="uploadRef && uploadRef.dropActive"
          class="fixed bottom-0 left-0 right-0 top-0 z-20 flex h-full w-full flex-col items-center justify-center gap-2 bg-modal-backdrop-light text-n-slate-12 dark:bg-modal-backdrop-dark"
        >
          <fluent-icon icon="cloud-backup" size="40" />
          <h4 class="break-words text-2xl text-n-slate-12">
            {{ t('IBSOFT_INTERNAL_CHAT.MESSAGES.DRAG_DROP') }}
          </h4>
        </div>
      </transition>
    </div>
    <div class="right-wrap">
      <Button
        :label="sendButtonText"
        type="submit"
        sm
        color="blue"
        :disabled="isSendDisabled"
        :is-loading="isSending"
        class="flex-shrink-0"
        @click="emit('send')"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.left-wrap {
  @apply items-center flex gap-2;
}

.right-wrap {
  @apply flex;
}

:deep(.file-uploads) {
  label {
    @apply cursor-pointer;
  }

  &:hover button {
    @apply enabled:bg-n-slate-9/20;
  }
}
</style>
