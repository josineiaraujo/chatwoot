<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TeleportWithDirection from 'dashboard/components-next/TeleportWithDirection.vue';
import { useAlert } from 'dashboard/composables';
import metaTemplatesAPI from '../api';
import {
  createEmptyTemplate,
  templateToDraft,
  validateStep,
} from '../templateModel';
import TemplateBasicsStep from './TemplateBasicsStep.vue';
import TemplateContentStep from './TemplateContentStep.vue';
import TemplateReviewStep from './TemplateReviewStep.vue';
import WhatsAppTemplatePreview from './WhatsAppTemplatePreview.vue';

const props = defineProps({
  inboxId: { type: [String, Number], required: true },
  templateId: { type: String, default: '' },
});

const emit = defineEmits(['close', 'saved']);
const { t } = useI18n();

const draft = ref(createEmptyTemplate());
const step = ref(1);
const maxVisitedStep = ref(1);
const errors = ref({});
const isLoading = ref(false);
const isSaving = ref(false);
const isUploading = ref(false);
const uploadProgress = ref(0);
const showMobilePreview = ref(false);
const initialSnapshot = ref('');

const editMode = computed(() => Boolean(props.templateId));
const title = computed(() =>
  editMode.value
    ? t('IBSOFT_META_TEMPLATES.EDITOR.EDIT_TITLE')
    : t('IBSOFT_META_TEMPLATES.EDITOR.CREATE_TITLE')
);
const mobilePreviewLabel = computed(() =>
  showMobilePreview.value
    ? t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.CLOSE')
    : t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.OPEN')
);
const submitLabel = computed(() =>
  editMode.value
    ? t('IBSOFT_META_TEMPLATES.EDITOR.SAVE')
    : t('IBSOFT_META_TEMPLATES.EDITOR.CREATE')
);
const steps = computed(() => [
  {
    id: 1,
    label: t('IBSOFT_META_TEMPLATES.EDITOR.STEPS.SETUP'),
    icon: 'i-lucide-settings-2',
  },
  {
    id: 2,
    label: t('IBSOFT_META_TEMPLATES.EDITOR.STEPS.CONTENT'),
    icon: 'i-lucide-message-square-text',
  },
  {
    id: 3,
    label: t('IBSOFT_META_TEMPLATES.EDITOR.STEPS.REVIEW'),
    icon: 'i-lucide-check-check',
  },
]);
const changed = computed(
  () =>
    initialSnapshot.value &&
    JSON.stringify(draft.value) !== initialSnapshot.value
);

const loadTemplate = async () => {
  if (!editMode.value) {
    initialSnapshot.value = JSON.stringify(draft.value);
    return;
  }

  isLoading.value = true;
  try {
    const { data } = await metaTemplatesAPI.getTemplate(
      props.inboxId,
      props.templateId
    );
    draft.value = templateToDraft(data.template);
    initialSnapshot.value = JSON.stringify(draft.value);
  } catch {
    useAlert(t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.LOAD'));
    emit('close');
  } finally {
    isLoading.value = false;
  }
};

const goToStep = target => {
  if (target > maxVisitedStep.value) return;
  step.value = target;
  errors.value = {};
};

const continueStep = () => {
  errors.value = validateStep(draft.value, step.value);
  if (Object.keys(errors.value).length) {
    useAlert(
      step.value === 1
        ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.SETUP')
        : t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT')
    );
    return;
  }

  step.value += 1;
  maxVisitedStep.value = Math.max(maxVisitedStep.value, step.value);
};

const previousStep = () => {
  step.value = Math.max(1, step.value - 1);
  errors.value = {};
};

const close = () => {
  if (
    changed.value &&
    // eslint-disable-next-line no-alert
    !window.confirm(t('IBSOFT_META_TEMPLATES.EDITOR.UNSAVED'))
  )
    return;
  emit('close');
};

const save = async () => {
  errors.value = {
    ...validateStep(draft.value, 1),
    ...validateStep(draft.value, 2),
  };
  if (Object.keys(errors.value).length) {
    step.value = Object.keys(validateStep(draft.value, 1)).length ? 1 : 2;
    useAlert(t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT'));
    return;
  }

  isSaving.value = true;
  let saved = false;
  try {
    if (editMode.value) {
      await metaTemplatesAPI.updateTemplate(
        props.inboxId,
        props.templateId,
        draft.value
      );
    } else {
      await metaTemplatesAPI.createTemplate(props.inboxId, draft.value);
    }
    initialSnapshot.value = JSON.stringify(draft.value);
    useAlert(
      editMode.value
        ? t('IBSOFT_META_TEMPLATES.SUCCESS.UPDATED')
        : t('IBSOFT_META_TEMPLATES.SUCCESS.CREATED')
    );
    saved = true;
    emit('saved');
  } catch (error) {
    const message = error.response?.data?.message;
    useAlert(message || t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.SAVE'));
    const details = error.response?.data?.details || [];
    errors.value = Object.fromEntries(
      details.map(detail => [detail.field, true])
    );
  } finally {
    if (!saved) isSaving.value = false;
  }
};

const upload = async file => {
  isUploading.value = true;
  uploadProgress.value = 0;
  try {
    const { data } = await metaTemplatesAPI.uploadMedia(
      props.inboxId,
      file,
      event => {
        if (!event.total) return;
        uploadProgress.value = Math.round((event.loaded / event.total) * 100);
      }
    );
    draft.value.header.media_handle = data.handle;
    draft.value.header.media_filename = data.filename;
  } catch (error) {
    draft.value.header.media_handle = '';
    const message = error.response?.data?.message;
    useAlert(message || t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.UPLOAD'));
  } finally {
    isUploading.value = false;
  }
};

const handleEscape = event => {
  if (event.key === 'Escape') close();
};

onMounted(() => {
  document.addEventListener('keydown', handleEscape);
  loadTemplate();
});

onBeforeUnmount(() => {
  document.removeEventListener('keydown', handleEscape);
  if (draft.value.header.media_preview_url?.startsWith('blob:')) {
    URL.revokeObjectURL(draft.value.header.media_preview_url);
  }
});
</script>

<template>
  <TeleportWithDirection to="body">
    <div
      class="fixed inset-0 z-[100] flex min-h-0 flex-col bg-n-background"
      data-testid="meta-template-workspace"
    >
      <header
        class="flex h-16 shrink-0 items-center justify-between gap-4 border-b border-n-weak px-4 md:px-6"
      >
        <div class="flex min-w-0 items-center gap-3">
          <Button
            icon="i-lucide-x"
            color="slate"
            variant="ghost"
            :aria-label="t('IBSOFT_META_TEMPLATES.EDITOR.CANCEL')"
            @click="close"
          />
          <h1 class="m-0 truncate text-heading-1 text-n-slate-12">
            {{ title }}
          </h1>
        </div>
        <div class="flex min-w-0 items-center gap-2">
          <span class="hidden truncate text-xs text-n-slate-10 sm:block">
            {{ draft.name }}
          </span>
          <Button
            class="md:hidden"
            :icon="
              showMobilePreview ? 'i-lucide-pencil' : 'i-lucide-message-square'
            "
            color="slate"
            variant="ghost"
            :aria-label="mobilePreviewLabel"
            @click="showMobilePreview = !showMobilePreview"
          />
        </div>
      </header>

      <div v-if="isLoading" class="grid min-h-0 flex-1 place-content-center">
        <Spinner />
      </div>

      <div v-else class="flex min-h-0 flex-1 flex-col">
        <nav
          class="shrink-0 overflow-x-auto border-b border-n-weak px-4 py-3 md:px-6"
        >
          <div class="mx-auto grid min-w-[32rem] max-w-4xl grid-cols-3 gap-2">
            <button
              v-for="item in steps"
              :key="item.id"
              type="button"
              class="flex items-center justify-center gap-3 rounded-lg px-3 py-3 text-sm font-medium text-n-slate-11 transition-colors"
              :class="{
                'bg-n-alpha-2 text-n-slate-12': step === item.id,
                'cursor-not-allowed opacity-50': item.id > maxVisitedStep,
                'hover:bg-n-alpha-1': item.id <= maxVisitedStep,
              }"
              :disabled="item.id > maxVisitedStep"
              @click="goToStep(item.id)"
            >
              <span
                class="grid size-7 shrink-0 place-content-center rounded-full border border-n-weak"
                :class="{
                  'border-n-brand bg-n-brand text-white': step === item.id,
                }"
              >
                <i class="size-4" :class="item.icon" />
              </span>
              {{ item.label }}
            </button>
          </div>
        </nav>

        <div class="flex min-h-0 flex-1">
          <main class="min-h-0 min-w-0 flex-1 overflow-y-auto">
            <div class="mx-auto w-full max-w-4xl p-5 pb-28 md:p-6 md:pb-28">
              <TemplateBasicsStep
                v-if="step === 1"
                v-model="draft"
                :edit-mode="editMode"
                :errors="errors"
              />
              <TemplateContentStep
                v-else-if="step === 2"
                v-model="draft"
                :errors="errors"
                :uploading="isUploading"
                :upload-progress="uploadProgress"
                @upload="upload"
              />
              <TemplateReviewStep v-else :draft="draft" />
            </div>
          </main>

          <aside
            class="hidden min-h-0 w-80 shrink-0 overflow-y-auto border-l border-n-weak p-4 md:block lg:w-96 lg:p-5"
          >
            <WhatsAppTemplatePreview :draft="draft" />
          </aside>
        </div>
      </div>

      <div
        v-if="!isLoading && showMobilePreview"
        class="absolute inset-x-0 bottom-16 top-16 z-20 overflow-y-auto bg-n-background p-4 md:hidden"
      >
        <WhatsAppTemplatePreview :draft="draft" />
      </div>

      <footer
        v-if="!isLoading"
        class="absolute inset-x-0 bottom-0 flex min-h-16 items-center justify-between gap-3 border-t border-n-weak bg-n-background/95 px-4 py-3 backdrop-blur md:px-6"
      >
        <Button
          v-if="step > 1"
          color="slate"
          variant="outline"
          icon="i-lucide-arrow-left"
          :label="t('IBSOFT_META_TEMPLATES.EDITOR.BACK')"
          @click="previousStep"
        />
        <span v-else />
        <Button
          v-if="step < 3"
          trailing-icon
          icon="i-lucide-arrow-right"
          :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTINUE')"
          @click="continueStep"
        />
        <Button
          v-else
          icon="i-lucide-send"
          :is-loading="isSaving"
          :disabled="isSaving || isUploading"
          :label="submitLabel"
          @click="save"
        />
      </footer>
    </div>
  </TeleportWithDirection>
</template>
