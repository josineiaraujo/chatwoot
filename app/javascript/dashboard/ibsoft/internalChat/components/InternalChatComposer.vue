<script setup>
import { computed, defineAsyncComponent, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useKbd } from 'dashboard/composables/utils/useKbd';

import AttachmentPreview from 'dashboard/components/widgets/AttachmentsPreview.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import InternalChatReplyBottomPanel from './InternalChatReplyBottomPanel.vue';
import InternalChatReplyTopPanel from './InternalChatReplyTopPanel.vue';

import { AUDIO_FORMATS } from 'shared/constants/messages';
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

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();
const { isEditorHotKeyEnabled } = useUISettings();
const shortcutKey = useKbd(['$mod', '+', 'enter']);
const globalConfig = useMapGetter('globalConfig/get');

const messageEditor = ref(null);
const audioRecorderInput = ref(null);
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
      <InternalChatReplyTopPanel
        @toggle-editor-size="emit('toggleEditorSize')"
      />
      <div class="reply-box__top">
        <EmojiIconPicker
          v-if="showEmojiPicker"
          v-on-clickaway="hideEmojiPicker"
          mode="emoji"
          class="emoji-dialog"
          @select="addIntoEditor($event.value)"
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
          class="input popover-prosemirror-menu internal-chat-editor"
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

      <InternalChatReplyBottomPanel
        :disabled="disabled"
        :is-recording-audio="isRecordingAudio"
        :is-send-disabled="isSendDisabled"
        :is-sending="isSending"
        :recording-audio-duration-text="recordingAudioDurationText"
        :recording-audio-state="recordingAudioState"
        :send-button-text="sendButtonText"
        @file-upload="onFileUpload"
        @send="emitSend"
        @toggle-audio-recorder="toggleAudioRecorder"
        @toggle-audio-recorder-play-pause="toggleAudioRecorderPlayPause"
        @toggle-emoji-picker="toggleEmojiPicker"
      />
    </div>
  </div>
</template>

<style lang="scss" scoped>
.internal-chat-composer {
  @apply w-full;
}

.reply-box {
  @apply relative mb-2 mx-2 border border-n-weak rounded-xl bg-n-solid-1;
}

.reply-box__top {
  @apply relative -mt-px py-0 ltr:pl-3 ltr:pr-12 rtl:pl-12 rtl:pr-3;
}

.emoji-dialog {
  @apply top-[unset] -bottom-10 ltr:-left-80 ltr:right-[unset] rtl:left-[unset] rtl:-right-80;

  &::before {
    filter: drop-shadow(0px 4px 4px rgba(0, 0, 0, 0.08));
    @apply ltr:-right-4 bottom-2 rtl:-left-4 ltr:rotate-[270deg] rtl:rotate-[90deg];
  }
}

::v-deep .internal-chat-editor .ProseMirror-menubar-wrapper {
  @apply gap-3;
}

::v-deep .internal-chat-editor .ProseMirror-woot-style {
  @apply pr-1;
}
</style>
