<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import languages from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import {
  CATEGORY_MODELS,
  convertTemplateVariableFormat,
  defaultHeaderFormat,
  extractVariables,
  finalizeTemplateName,
  getTemplateModelDefinition,
  sanitizeTemplateName,
} from '../templateModel';

defineProps({
  editMode: { type: Boolean, default: false },
  errors: { type: Object, default: () => ({}) },
});

const draft = defineModel({ type: Object, required: true });
const { t } = useI18n();

const categoryOptions = computed(() => [
  {
    value: 'MARKETING',
    label: t('IBSOFT_META_TEMPLATES.CATEGORY.MARKETING'),
    icon: 'i-lucide-megaphone',
  },
  {
    value: 'UTILITY',
    label: t('IBSOFT_META_TEMPLATES.CATEGORY.UTILITY'),
    icon: 'i-lucide-bell',
  },
  {
    value: 'AUTHENTICATION',
    label: t('IBSOFT_META_TEMPLATES.CATEGORY.AUTHENTICATION'),
    icon: 'i-lucide-key-round',
  },
]);

const modelPresentations = computed(() => ({
  standard: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.STANDARD'),
    description: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.STANDARD_DESCRIPTION'),
  },
  catalog: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.CATALOG'),
    description: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.CATALOG_DESCRIPTION'),
  },
  order_details: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.ORDER_DETAILS'),
    description: t(
      'IBSOFT_META_TEMPLATES.EDITOR.SETUP.ORDER_DETAILS_DESCRIPTION'
    ),
  },
  order_status: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.ORDER_STATUS'),
    description: t(
      'IBSOFT_META_TEMPLATES.EDITOR.SETUP.ORDER_STATUS_DESCRIPTION'
    ),
  },
  call_permission_request: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.CALL_PERMISSION_REQUEST'),
    description: t(
      'IBSOFT_META_TEMPLATES.EDITOR.SETUP.CALL_PERMISSION_REQUEST_DESCRIPTION'
    ),
  },
  authentication: {
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.AUTHENTICATION'),
    description: t(
      'IBSOFT_META_TEMPLATES.EDITOR.SETUP.AUTHENTICATION_DESCRIPTION'
    ),
  },
}));

const variableFormatOptions = computed(() => [
  {
    value: 'named',
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.NAMED'),
  },
  {
    value: 'positional',
    label: t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.POSITIONAL'),
  },
]);

const languageOptions = computed(() =>
  languages.map(language => ({
    value: language.id,
    label: `${language.name} (${language.id})`,
  }))
);

const templateName = computed({
  get: () => draft.value.name,
  set: value => {
    draft.value.name = sanitizeTemplateName(value);
  },
});

const finalizeName = () => {
  draft.value.name = finalizeTemplateName(draft.value.name);
};

const modelOptions = computed(() => {
  const models = CATEGORY_MODELS[draft.value.category] || [];
  return models.map(value => ({
    value,
    ...modelPresentations.value[value],
    icon: getTemplateModelDefinition(value).icon,
  }));
});

const normalizeModelFields = model => {
  const definition = getTemplateModelDefinition(model);
  if (!definition.headerFormats.includes(draft.value.header.format)) {
    draft.value.header.format = defaultHeaderFormat(model);
  }
  if (!definition.genericButtons) draft.value.buttons = [];
};

const setParameterFormat = format => {
  if (draft.value.parameter_format === format) return;

  const hasVariables = ['header', 'body'].some(
    section =>
      extractVariables(draft.value[section].text, draft.value.parameter_format)
        .length
  );

  if (
    hasVariables &&
    // eslint-disable-next-line no-alert
    !window.confirm(
      t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.VARIABLE_FORMAT_CONFIRM')
    )
  ) {
    return;
  }

  convertTemplateVariableFormat(draft.value, format);
};

watch(
  () => draft.value.category,
  category => {
    const models = CATEGORY_MODELS[category] || [];
    if (!models.includes(draft.value.model)) draft.value.model = models[0];
  }
);

watch(
  () => draft.value.model,
  model => normalizeModelFields(model)
);
</script>

<template>
  <div class="grid gap-7" data-testid="meta-template-basics">
    <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_18rem]">
      <Input
        v-model="templateName"
        :label="t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.NAME')"
        :placeholder="t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.NAME_PLACEHOLDER')"
        :disabled="editMode"
        maxlength="512"
        :message="
          errors.name ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.SETUP') : ''
        "
        :message-type="errors.name ? 'error' : 'info'"
        @blur="finalizeName"
      />
      <label class="grid min-w-0 gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.LANGUAGE') }}
        </span>
        <ComboBox
          v-model="draft.language"
          :options="languageOptions"
          :disabled="editMode"
          :has-error="Boolean(errors.language)"
          :search-placeholder="t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.LANGUAGE')"
        />
      </label>
    </div>

    <fieldset class="grid gap-3">
      <legend class="mb-1 text-heading-2 text-n-slate-12">
        {{ t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.CATEGORY') }}
      </legend>
      <div
        class="grid overflow-hidden rounded-lg border border-n-weak sm:grid-cols-3"
      >
        <button
          v-for="category in categoryOptions"
          :key="category.value"
          type="button"
          class="flex min-h-12 items-center justify-center gap-2 border-n-weak px-4 py-3 text-sm font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-1 hover:text-n-slate-12 sm:border-r sm:last:border-r-0"
          :class="{
            'bg-n-alpha-2 text-n-brand outline outline-1 -outline-offset-1 outline-n-brand':
              draft.category === category.value,
          }"
          @click="draft.category = category.value"
        >
          <i class="size-4" :class="category.icon" />
          {{ category.label }}
        </button>
      </div>
    </fieldset>

    <fieldset class="grid gap-3">
      <legend class="mb-1 text-heading-2 text-n-slate-12">
        {{ t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.MODEL') }}
      </legend>
      <div class="grid gap-3 md:grid-cols-2">
        <button
          v-for="model in modelOptions"
          :key="model.value"
          type="button"
          class="flex min-h-20 items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4 text-left transition-colors hover:border-n-strong"
          :class="{
            'border-n-brand outline outline-1 outline-n-brand':
              draft.model === model.value,
          }"
          @click="draft.model = model.value"
        >
          <i class="mt-0.5 size-5 text-n-brand" :class="model.icon" />
          <span class="grid gap-1">
            <strong class="text-sm font-medium text-n-slate-12">
              {{ model.label }}
            </strong>
            <span class="text-xs text-n-slate-11">
              {{ model.description }}
            </span>
          </span>
        </button>
      </div>
    </fieldset>

    <fieldset v-if="draft.model !== 'authentication'" class="grid gap-3">
      <legend class="mb-1 text-heading-2 text-n-slate-12">
        {{ t('IBSOFT_META_TEMPLATES.EDITOR.SETUP.VARIABLE_FORMAT') }}
      </legend>
      <div
        class="grid max-w-md overflow-hidden rounded-lg border border-n-weak sm:grid-cols-2"
      >
        <button
          v-for="format in variableFormatOptions"
          :key="format.value"
          type="button"
          class="px-4 py-3 text-sm font-medium text-n-slate-11 transition-colors hover:bg-n-alpha-1"
          :class="{
            'bg-n-alpha-2 text-n-brand':
              draft.parameter_format === format.value,
          }"
          @click="setParameterFormat(format.value)"
        >
          {{ format.label }}
        </button>
      </div>
    </fieldset>
  </div>
</template>
