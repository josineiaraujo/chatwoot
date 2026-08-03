<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import WhatsAppTemplatePreview from '../../metaTemplates/components/WhatsAppTemplatePreview.vue';
import { templateToDraft } from '../../metaTemplates/templateModel';

const props = defineProps({
  template: {
    type: Object,
    default: null,
  },
  variables: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();

const mediaFilename = value => {
  try {
    return decodeURIComponent(new URL(value).pathname.split('/').pop() || '');
  } catch {
    return '';
  }
};

const previewButtons = template => {
  const component = (template.components || []).find(
    item => String(item.type || '').toUpperCase() === 'BUTTONS'
  );
  const supportedTypes = ['QUICK_REPLY', 'URL', 'PHONE_NUMBER', 'COPY_CODE'];

  return (component?.buttons || [])
    .filter(button =>
      supportedTypes.includes(String(button.type || '').toUpperCase())
    )
    .map(button => ({
      type: String(button.type || '').toUpperCase(),
      text: button.text || '',
      url: button.url || '',
      phone_number: button.phone_number || '',
      example: button.example?.[0] || '',
    }));
};

const previewDraft = computed(() => {
  if (!props.template) return null;

  const draft = templateToDraft(props.template);
  if (draft.model === 'standard') {
    draft.buttons = previewButtons(props.template);
  }
  const mediaVariable = props.variables.find(
    variable =>
      variable.component_type === 'HEADER' &&
      variable.parameter_type === 'media'
  );

  if (mediaVariable?.value) {
    draft.header.media_preview_url = mediaVariable.value;
    draft.header.media_filename = mediaFilename(mediaVariable.value);
  }

  return draft;
});
</script>

<template>
  <section
    v-if="!previewDraft"
    class="rounded-xl bg-n-alpha-1 p-4 outline outline-1 outline-n-weak"
  >
    <h2 class="font-medium text-n-slate-12">
      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_PREVIEW') }}
    </h2>

    <div class="mt-4 text-sm text-n-slate-11">
      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.TEMPLATE_PREVIEW_EMPTY') }}
    </div>
  </section>

  <WhatsAppTemplatePreview v-else :draft="previewDraft" />
</template>
