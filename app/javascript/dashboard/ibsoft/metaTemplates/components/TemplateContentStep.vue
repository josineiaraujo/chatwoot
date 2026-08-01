<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { getTemplateModelDefinition, sanitizeExamples } from '../templateModel';
import TemplateVariableField from './TemplateVariableField.vue';

defineProps({
  errors: { type: Object, default: () => ({}) },
  uploading: { type: Boolean, default: false },
  uploadProgress: { type: Number, default: 0 },
});

const emit = defineEmits(['upload']);
const draft = defineModel({ type: Object, required: true });
const { t } = useI18n();
const fileInput = ref(null);

const modelDefinition = computed(() =>
  getTemplateModelDefinition(draft.value.model)
);
const availableHeaderFormats = computed(
  () => modelDefinition.value.headerFormats
);
const supportsHeader = computed(
  () =>
    availableHeaderFormats.value.length > 1 ||
    availableHeaderFormats.value[0] !== 'NONE'
);
const supportsGenericButtons = computed(
  () => modelDefinition.value.genericButtons
);
const fixedButtonTextLabel = computed(() => {
  if (draft.value.model === 'catalog') {
    return t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.CATALOG_TEXT');
  }

  return '';
});

const acceptedMedia = computed(
  () =>
    ({
      IMAGE: 'image/jpeg,image/png',
      VIDEO: 'video/mp4',
      DOCUMENT: 'application/pdf',
    })[draft.value.header.format] || ''
);

const headerFormatLabels = computed(() => ({
  NONE: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.NONE'),
  TEXT: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.TEXT'),
  IMAGE: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.IMAGE'),
  VIDEO: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.VIDEO'),
  DOCUMENT: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.DOCUMENT'),
}));

const buttonTypeOptions = computed(() => [
  {
    value: 'QUICK_REPLY',
    label: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.QUICK_REPLY'),
  },
  {
    value: 'URL',
    label: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.URL'),
  },
  {
    value: 'PHONE_NUMBER',
    label: t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.PHONE_NUMBER'),
  },
]);

const uploadButtonLabel = computed(() =>
  draft.value.header.media_filename
    ? t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.REPLACE_UPLOAD')
    : t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.UPLOAD')
);

const addButton = () => {
  if (draft.value.buttons.length >= 10) return;
  draft.value.buttons.push({
    type: 'QUICK_REPLY',
    text: '',
    url: '',
    phone_number: '',
    example: '',
  });
};

const removeButton = index => {
  draft.value.buttons.splice(index, 1);
};

const selectFile = event => {
  const file = event.target.files?.[0];
  if (!file) return;

  if (draft.value.header.media_preview_url?.startsWith('blob:')) {
    URL.revokeObjectURL(draft.value.header.media_preview_url);
  }
  draft.value.header.media_preview_url = URL.createObjectURL(file);
  emit('upload', file);
  event.target.value = '';
};

watch(
  () => [
    draft.value.header.text,
    draft.value.body.text,
    draft.value.parameter_format,
  ],
  () => sanitizeExamples(draft.value),
  { deep: true }
);

watch(
  () => draft.value.header.format,
  (format, previousFormat) => {
    if (format === previousFormat) return;
    if (format !== 'TEXT') draft.value.header.text = '';
    if (!['IMAGE', 'VIDEO', 'DOCUMENT'].includes(format)) {
      draft.value.header.media_handle = '';
      draft.value.header.media_filename = '';
      draft.value.header.media_preview_url = '';
    }
  }
);
</script>

<template>
  <div class="grid gap-7" data-testid="meta-template-content">
    <template v-if="draft.model === 'authentication'">
      <label
        class="flex items-center gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <Checkbox v-model="draft.authentication.add_security_recommendation" />
        <span class="text-sm font-medium text-n-slate-12">
          {{
            t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.SECURITY_RECOMMENDATION')
          }}
        </span>
      </label>
      <Input
        v-model="draft.authentication.code_expiration_minutes"
        type="number"
        min="1"
        max="90"
        :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.CODE_EXPIRATION')"
        :message="
          errors.expiration
            ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT')
            : ''
        "
        :message-type="errors.expiration ? 'error' : 'info'"
        class="max-w-xs"
      />
    </template>

    <template v-else>
      <section v-if="supportsHeader" class="grid gap-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <h2 class="m-0 text-heading-2 text-n-slate-12">
            {{ t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.HEADER') }}
          </h2>
          <div
            class="flex max-w-full gap-1 overflow-x-auto rounded-lg bg-n-alpha-2 p-1"
          >
            <button
              v-for="format in availableHeaderFormats"
              :key="format"
              type="button"
              class="shrink-0 rounded-md px-3 py-2 text-xs font-medium text-n-slate-11 transition-colors hover:text-n-slate-12"
              :class="{
                'bg-n-solid-2 text-n-slate-12 shadow-sm':
                  draft.header.format === format,
              }"
              @click="draft.header.format = format"
            >
              {{ headerFormatLabels[format] }}
            </button>
          </div>
        </div>

        <TemplateVariableField
          v-if="draft.header.format === 'TEXT'"
          v-model:text="draft.header.text"
          v-model:examples="draft.header.examples"
          field-id="ibsoft-meta-template-header"
          :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.HEADER_TEXT')"
          :parameter-format="draft.parameter_format"
          :has-example-error="Boolean(errors.headerExamples)"
        >
          <Input
            id="ibsoft-meta-template-header"
            v-model="draft.header.text"
            :message="
              errors.header
                ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT')
                : ''
            "
            :message-type="errors.header ? 'error' : 'info'"
            maxlength="60"
          />
        </TemplateVariableField>

        <div
          v-if="['IMAGE', 'VIDEO', 'DOCUMENT'].includes(draft.header.format)"
          class="flex flex-wrap items-center gap-3 rounded-lg border border-dashed border-n-strong bg-n-alpha-1 p-4"
        >
          <input
            ref="fileInput"
            type="file"
            class="sr-only"
            :accept="acceptedMedia"
            @change="selectFile"
          />
          <Button
            type="button"
            icon="i-lucide-upload"
            color="slate"
            variant="outline"
            :disabled="uploading"
            :label="uploadButtonLabel"
            @click="fileInput?.click()"
          />
          <p class="m-0 min-w-0 text-sm text-n-slate-11">
            {{
              uploading
                ? t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.UPLOADING', {
                    progress: uploadProgress,
                  })
                : draft.header.media_filename
                  ? t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.MEDIA_READY', {
                      name: draft.header.media_filename,
                    })
                  : ''
            }}
          </p>
          <div
            v-if="uploading"
            class="h-1.5 w-full overflow-hidden rounded-full bg-n-alpha-2"
          >
            <span
              class="block h-full rounded-full bg-n-brand transition-[width]"
              :style="{ width: `${uploadProgress}%` }"
            />
          </div>
          <p v-if="errors.media" class="m-0 w-full text-xs text-n-ruby-10">
            {{ t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT') }}
          </p>
        </div>
      </section>

      <TemplateVariableField
        v-model:text="draft.body.text"
        v-model:examples="draft.body.examples"
        field-id="ibsoft-meta-template-body"
        :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BODY')"
        :parameter-format="draft.parameter_format"
        :has-example-error="Boolean(errors.bodyExamples)"
      >
        <TextArea
          id="ibsoft-meta-template-body"
          v-model="draft.body.text"
          :placeholder="
            t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BODY_PLACEHOLDER')
          "
          :max-length="1024"
          show-character-count
          resize
          min-height="10rem"
          :message="
            errors.body ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT') : ''
          "
          :message-type="errors.body ? 'error' : 'info'"
        />
      </TemplateVariableField>

      <Input
        v-model="draft.footer.text"
        :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.FOOTER')"
        :placeholder="
          t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.FOOTER_PLACEHOLDER')
        "
        maxlength="60"
        :message="
          errors.footer ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT') : ''
        "
        :message-type="errors.footer ? 'error' : 'info'"
      />

      <Input
        v-if="modelDefinition.fixedButtonTextEditable"
        v-model="draft.special.button_text"
        :label="fixedButtonTextLabel"
        maxlength="25"
        :message="
          errors.specialAction
            ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT')
            : ''
        "
        :message-type="errors.specialAction ? 'error' : 'info'"
      />

      <div
        v-if="draft.model === 'call_permission_request'"
        class="flex items-center gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <i class="i-lucide-phone size-5 text-n-brand" />
        <span class="text-sm font-medium text-n-slate-12">
          {{
            t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.CALL_PERMISSION_INCLUDED')
          }}
        </span>
      </div>

      <section v-if="supportsGenericButtons" class="grid gap-4">
        <div class="flex items-center justify-between gap-3">
          <h2 class="m-0 text-heading-2 text-n-slate-12">
            {{ t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTONS') }}
          </h2>
          <Button
            type="button"
            icon="i-lucide-plus"
            color="slate"
            variant="outline"
            size="sm"
            :disabled="draft.buttons.length >= 10"
            :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.ADD_BUTTON')"
            @click="addButton"
          />
        </div>

        <div
          v-for="(button, index) in draft.buttons"
          :key="index"
          class="grid items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4 md:grid-cols-[14rem_minmax(0,1fr)_2.5rem]"
        >
          <label class="grid min-w-0 content-start gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTON_TYPE') }}
            </span>
            <span class="relative block min-w-0">
              <select
                v-model="button.type"
                :data-testid="`template-button-type-${index}`"
                class="!mb-0 block h-10 w-full appearance-none rounded-lg border-0 bg-n-alpha-1 px-3 pe-10 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-transparent transition-colors hover:outline-n-weak focus:outline-n-brand"
              >
                <option
                  v-for="option in buttonTypeOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <i
                aria-hidden="true"
                :data-testid="`template-button-type-icon-${index}`"
                class="i-lucide-chevron-down pointer-events-none absolute end-3 top-1/2 size-4 -translate-y-1/2 text-n-slate-11"
              />
            </span>
          </label>
          <div class="grid gap-3">
            <Input
              v-model="button.text"
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTON_TEXT')"
              maxlength="25"
            />
            <Input
              v-if="button.type === 'URL'"
              v-model="button.url"
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTON_URL')"
            />
            <Input
              v-if="button.type === 'URL' && button.url.includes('{{')"
              v-model="button.example"
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTON_EXAMPLE')"
            />
            <Input
              v-if="button.type === 'PHONE_NUMBER'"
              v-model="button.phone_number"
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.BUTTON_PHONE')"
            />
          </div>
          <Button
            type="button"
            icon="i-lucide-trash-2"
            color="ruby"
            variant="ghost"
            size="sm"
            class="justify-self-end md:mt-5"
            :aria-label="
              t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.REMOVE_BUTTON')
            "
            @click="removeButton(index)"
          />
        </div>
      </section>
    </template>
  </div>
</template>
