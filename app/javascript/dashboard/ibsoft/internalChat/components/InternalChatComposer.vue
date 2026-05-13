<script setup>
import { computed, defineAsyncComponent, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import FileUpload from 'vue-upload-component';

import { useAlert } from 'dashboard/composables';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKbd } from 'dashboard/composables/utils/useKbd';

import Button from 'dashboard/components-next/button/Button.vue';
import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

import { ALLOWED_FILE_TYPES, AUDIO_FORMATS } from 'shared/constants/messages';
import {
  checkFileSizeLimit,
  resolveMaximumFileUploadSize,
} from 'shared/helpers/FileHelper';

const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  attachments: {
    type: Array,
    default: () => [],
  },
  roomId: {
    type: Number,
    required: true,
  },
  canSend: {
    type: Boolean,
    default: false,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isSending: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'blur',
  'focus',
  'send',
  'toggleEditorSize',
  'update:attachments',
  'update:modelValue',
]);

const EmojiInput = defineAsyncComponent(
  () => import('shared/components/emoji/EmojiInput.vue')
);

const { t } = useI18n();
const { isEditorHotKeyEnabled } = useUISettings();
const shortcutKey = useKbd(['$mod', '+', 'enter']);
const globalConfig = useMapGetter('globalConfig/get');

const messageEditor = ref(null);
const audioRecorderInput = ref(null);
const uploadRef = ref(null);
const isFocused = ref(false);
const showEmojiPicker = ref(false);
const isRecordingAudio = ref(false);
const recordingAudioState = ref('');
const recordingAudioDurationText = ref('00:00');
const updateEditorSelectionWith = ref('');
let attachmentSequence = 0;

const composerMessage = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value),
});

const composerAttachments = computed({
  get: () => props.attachments,
  set: value => emit('update:attachments', value),
});

const uploadLimit = computed(() =>
  resolveMaximumFileUploadSize(globalConfig.value?.maximumFileUploadSize)
);

const hasAttachments = computed(() => props.attachments.length > 0);
const hasVisibleAttachments = computed(() =>
  props.attachments.some(attachment => !attachment?.isRecordedAudio)
);

const isSendDisabled = computed(
  () => props.disabled || props.isSending || !props.canSend
);

const sendButtonText = computed(() => {
  const keyLabel = isEditorHotKeyEnabled('cmd_enter')
    ? `(${shortcutKey.value})`
    : '(↵)';
  return `${t('IBSOFT_INTERNAL_CHAT.ACTIONS.SEND')} ${keyLabel}`;
});

const audioRecorderPlayStopIcon = computed(() => {
  switch (recordingAudioState.value) {
    case 'playing':
      return 'i-ph-pause';
    case 'paused':
    case 'stopped':
      return 'i-ph-play';
    default:
      return 'i-ph-stop';
  }
});

const attachmentId = () => {
  attachmentSequence += 1;
  return `ibsoft-internal-attachment-${Date.now()}-${attachmentSequence}`;
};

const hideEmojiPicker = () => {
  showEmojiPicker.value = false;
};

const toggleEmojiPicker = () => {
  showEmojiPicker.value = !showEmojiPicker.value;
};

const clearEditorSelection = () => {
  updateEditorSelectionWith.value = '';
};

const onFocus = () => {
  isFocused.value = true;
  emit('focus');
};

const onBlur = () => {
  isFocused.value = false;
  emit('blur');
};

const addIntoEditor = content => {
  updateEditorSelectionWith.value = content;
  onFocus();
};

const emitSend = () => {
  if (isSendDisabled.value) return;
  emit('send');
};

const resetAudioRecorderInput = () => {
  recordingAudioDurationText.value = '00:00';
  isRecordingAudio.value = false;
  recordingAudioState.value = '';
  composerAttachments.value = props.attachments.filter(
    attachment => !attachment?.isRecordedAudio
  );
};

const toggleAudioRecorder = () => {
  isRecordingAudio.value = !isRecordingAudio.value;
  if (!isRecordingAudio.value) resetAudioRecorderInput();
};

const toggleAudioRecorderPlayPause = () => {
  if (!audioRecorderInput.value) return;
  if (!recordingAudioState.value) {
    audioRecorderInput.value.stopRecording();
    return;
  }

  audioRecorderInput.value.playPause();
};

const onRecordProgressChanged = duration => {
  recordingAudioDurationText.value = duration;
};

const createAttachmentResource = filePayload => {
  const rawFile = filePayload?.file || filePayload;
  return {
    name: filePayload?.name || rawFile.name,
    type: filePayload?.type || rawFile.type,
    size: filePayload?.size || rawFile.size,
    file: rawFile,
  };
};

const attachFile = filePayload => {
  const rawFile = filePayload?.file || filePayload;
  if (!rawFile || rawFile.size === 0) return;

  if (!checkFileSizeLimit({ file: rawFile }, uploadLimit.value)) {
    useAlert(
      t('IBSOFT_INTERNAL_CHAT.ERRORS.FILE_SIZE_LIMIT', {
        size: uploadLimit.value,
      })
    );
    return;
  }

  const reader = new FileReader();
  reader.readAsDataURL(rawFile);
  reader.onloadend = () => {
    composerAttachments.value = [
      ...props.attachments,
      {
        id: attachmentId(),
        resource: createAttachmentResource(filePayload),
        thumb: reader.result,
        isRecordedAudio: filePayload?.isRecordedAudio || false,
      },
    ];
  };
};

const onFileUpload = file => {
  attachFile(file);
};

const onPaste = event => {
  if (props.disabled) return;

  const files = Array.from(event.clipboardData?.files || []).filter(
    file => file.size > 0
  );
  if (!files.length) return;

  event.preventDefault();
  files.forEach(file =>
    attachFile({
      name: file.name,
      type: file.type,
      size: file.size,
      file,
    })
  );
};

const removeAttachment = attachments => {
  composerAttachments.value = attachments;
};

const onFinishRecorder = file => {
  if (!file) return;

  recordingAudioState.value = 'stopped';
  attachFile({
    ...file,
    isRecordedAudio: true,
  });
};

const isAValidEvent = selectedKey => {
  return (
    isFocused.value &&
    !showEmojiPicker.value &&
    !props.disabled &&
    isEditorHotKeyEnabled(selectedKey)
  );
};

useKeyboardEvents({
  Escape: {
    action: hideEmojiPicker,
    allowOnFocusedInput: true,
  },
  Enter: {
    action: event => {
      if (!isAValidEvent('enter')) return;
      emitSend();
      event.preventDefault();
    },
    allowOnFocusedInput: true,
  },
  '$mod+Enter': {
    action: event => {
      if (!isAValidEvent('cmd_enter')) return;
      emitSend();
      event.preventDefault();
    },
    allowOnFocusedInput: true,
  },
});

watch(
  () => props.attachments.length,
  (newLength, oldLength) => {
    if (oldLength > 0 && newLength === 0) {
      recordingAudioDurationText.value = '00:00';
      isRecordingAudio.value = false;
      recordingAudioState.value = '';
    }
  }
);
</script>

<template>
  <div class="internal-chat-composer">
    <div
      class="reply-box"
      :class="{ 'is-focused': isFocused || hasAttachments }"
      @paste="onPaste"
    >
      <div class="reply-box__top">
        <EmojiInput
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          class="emoji-dialog"
          :on-click="addIntoEditor"
        />
        <AudioRecorder
          v-if="isRecordingAudio"
          ref="audioRecorderInput"
          :audio-record-format="AUDIO_FORMATS.MP3"
          @recorder-progress-changed="onRecordProgressChanged"
          @finish-record="onFinishRecorder"
          @play="recordingAudioState = 'playing'"
          @pause="recordingAudioState = 'paused'"
        />
        <WootMessageEditor
          v-else
          ref="messageEditor"
          v-model="composerMessage"
          :conversation-id="roomId"
          :editor-id="`ibsoft-internal-chat-${roomId}`"
          class="input popover-prosemirror-menu"
          :placeholder="t('IBSOFT_INTERNAL_CHAT.MESSAGES.PLACEHOLDER')"
          :update-selection-with="updateEditorSelectionWith"
          :disabled="disabled"
          :enable-suggestions="false"
          @focus="onFocus"
          @blur="onBlur"
          @clear-selection="clearEditorSelection"
        />

        <div v-if="hasVisibleAttachments" class="mb-2 bg-transparent py-0">
          <AttachmentPreview
            class="mt-2"
            :attachments="attachments"
            @remove-attachment="removeAttachment"
          />
        </div>
      </div>

      <div class="flex justify-between p-3">
        <div class="left-wrap">
          <Button
            v-tooltip.top-end="
              t('IBSOFT_INTERNAL_CHAT.ACTIONS.SHOW_EMOJI_PICKER')
            "
            icon="i-ph-smiley-sticker"
            slate
            faded
            sm
            @click="toggleEmojiPicker"
          />
          <FileUpload
            ref="uploadRef"
            v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.ATTACH')"
            input-id="ibsoftInternalChatAttachment"
            :size="4096 * 4096"
            :accept="ALLOWED_FILE_TYPES"
            multiple
            drop
            :drop-directory="false"
            @input-file="onFileUpload"
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
            v-tooltip.top-end="t('IBSOFT_INTERNAL_CHAT.ACTIONS.RECORD_AUDIO')"
            :icon="
              !isRecordingAudio ? 'i-ph-microphone' : 'i-ph-microphone-slash'
            "
            slate
            faded
            sm
            @click="toggleAudioRecorder"
          />
          <Button
            v-if="isRecordingAudio"
            v-tooltip.top-end="
              t('IBSOFT_INTERNAL_CHAT.ACTIONS.TOGGLE_RECORDED_AUDIO')
            "
            :icon="audioRecorderPlayStopIcon"
            slate
            faded
            sm
            :label="recordingAudioDurationText"
            @click="toggleAudioRecorderPlayPause"
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
            v-tooltip.top-end="
              t('IBSOFT_INTERNAL_CHAT.ACTIONS.TOGGLE_COMPOSER_HEIGHT')
            "
            ghost
            class="text-n-slate-11"
            sm
            icon="i-lucide-maximize-2"
            @click="emit('toggleEditorSize')"
          />
          <Button
            :label="sendButtonText"
            type="submit"
            sm
            color="blue"
            :disabled="isSendDisabled"
            :is-loading="isSending"
            class="flex-shrink-0"
            @click="emitSend"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.internal-chat-composer {
  @apply w-full;
}

.reply-box {
  @apply relative mb-0 mx-0 border border-n-weak rounded-xl bg-n-solid-1;
}

.reply-box__top {
  @apply relative py-0 px-3 -mt-px;
}

.left-wrap {
  @apply items-center flex gap-2;
}

.right-wrap {
  @apply flex;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

::v-deep .file-uploads {
  label {
    @apply cursor-pointer;
  }

  &:hover button {
    @apply enabled:bg-n-slate-9/20;
  }
}
</style>
