<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  draft: { type: Object, required: true },
});

const { t } = useI18n();

const variableFormat = computed(() =>
  t(
    `IBSOFT_META_TEMPLATES.EDITOR.SETUP.${props.draft.parameter_format.toUpperCase()}`
  )
);

const templateFormat = computed(() =>
  t(`IBSOFT_META_TEMPLATES.EDITOR.SETUP.${props.draft.model.toUpperCase()}`)
);
</script>

<template>
  <div class="grid gap-6" data-testid="meta-template-review">
    <h2 class="m-0 text-heading-1 text-n-slate-12">
      {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.TITLE') }}
    </h2>

    <dl
      class="grid gap-px overflow-hidden rounded-lg border border-n-weak bg-n-weak sm:grid-cols-2"
    >
      <div class="grid gap-1 bg-n-background p-4">
        <dt class="text-xs text-n-slate-10">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.IDENTITY') }}
        </dt>
        <dd class="m-0 break-all text-sm font-medium text-n-slate-12">
          {{ draft.name }}
        </dd>
      </div>
      <div class="grid gap-1 bg-n-background p-4">
        <dt class="text-xs text-n-slate-10">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.CATEGORY') }}
        </dt>
        <dd class="m-0 text-sm font-medium text-n-slate-12">
          {{ t(`IBSOFT_META_TEMPLATES.CATEGORY.${draft.category}`) }}
        </dd>
      </div>
      <div class="grid gap-1 bg-n-background p-4">
        <dt class="text-xs text-n-slate-10">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.FORMAT') }}
        </dt>
        <dd class="m-0 text-sm font-medium text-n-slate-12">
          {{ templateFormat }}
        </dd>
      </div>
      <div class="grid gap-1 bg-n-background p-4">
        <dt class="text-xs text-n-slate-10">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.LANGUAGE') }}
        </dt>
        <dd class="m-0 text-sm font-medium text-n-slate-12">
          {{ draft.language }}
        </dd>
      </div>
      <div class="grid gap-1 bg-n-background p-4">
        <dt class="text-xs text-n-slate-10">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.VARIABLES') }}
        </dt>
        <dd class="m-0 text-sm font-medium text-n-slate-12">
          {{ variableFormat }}
        </dd>
      </div>
    </dl>

    <div
      class="flex items-start gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
    >
      <i class="i-lucide-shield-check mt-0.5 size-5 text-n-brand" />
      <div>
        <h3 class="m-0 text-sm font-medium text-n-slate-12">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.DESTINATION') }}
        </h3>
        <p class="mb-0 mt-1 text-sm text-n-slate-11">
          {{ t('IBSOFT_META_TEMPLATES.EDITOR.REVIEW.DESTINATION_DESCRIPTION') }}
        </p>
      </div>
    </div>
  </div>
</template>
