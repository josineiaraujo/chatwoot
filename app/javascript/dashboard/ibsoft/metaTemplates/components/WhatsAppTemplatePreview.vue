<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import { interpolatePreview } from '../templateModel';

const props = defineProps({
  draft: { type: Object, required: true },
});

const { locale, t } = useI18n();

const previewHeader = computed(() =>
  interpolatePreview(
    props.draft.header.text,
    props.draft.header.examples,
    props.draft.parameter_format
  )
);

const previewBody = computed(() =>
  interpolatePreview(
    props.draft.body.text,
    props.draft.body.examples,
    props.draft.parameter_format
  )
);

const previewButtons = computed(() =>
  props.draft.model === 'standard' ? props.draft.buttons : []
);

const previewTime = computed(() => {
  const normalizedLocale = String(locale.value || 'en').replace(/_/g, '-');

  try {
    return new Intl.DateTimeFormat(normalizedLocale, {
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date());
  } catch {
    return new Intl.DateTimeFormat('en', {
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date());
  }
});

const messageBody = computed(
  () =>
    previewBody.value || t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.BODY_EMPTY')
);

const orderReference = computed(
  () =>
    previewHeader.value ||
    t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ORDER_REFERENCE')
);

const orderActions = computed(() => [
  {
    icon: 'i-lucide-copy',
    text: t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.COPY_PIX_CODE'),
  },
  {
    icon: 'i-lucide-barcode',
    text: t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.COPY_BARCODE'),
  },
]);

const specialAction = computed(() => {
  const actions = {
    catalog: {
      icon: 'i-lucide-store',
      text:
        props.draft.special.button_text ||
        t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.VIEW_CATALOG'),
      className: 'text-n-brand',
    },
    call_permission_request: {
      icon: 'i-lucide-chevron-down',
      text: t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ALLOW_CALL'),
      className: 'text-n-teal-11',
    },
  };

  return actions[props.draft.model] || null;
});
</script>

<template>
  <aside class="grid min-w-0 gap-3" data-testid="meta-template-preview">
    <h2 class="m-0 text-heading-2 text-n-slate-12">
      {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.TITLE') }}
    </h2>
    <div
      class="whatsapp-preview-canvas relative isolate min-h-[32rem] overflow-hidden rounded-lg border border-n-weak bg-n-alpha-1 p-3 text-n-slate-9"
    >
      <div
        class="relative z-10 mx-auto mt-5 max-w-[22rem] overflow-hidden rounded-xl bg-n-solid-2 text-n-slate-12 shadow-lg"
        data-testid="preview-message"
      >
        <template v-if="draft.model === 'authentication'">
          <div class="grid gap-3 p-3">
            <p class="m-0 whitespace-pre-wrap text-sm text-n-slate-12">
              {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.AUTH_CODE') }}
            </p>
            <p
              v-if="draft.authentication.add_security_recommendation"
              class="m-0 text-xs text-n-slate-11"
            >
              {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.SECURITY') }}
            </p>
            <p class="m-0 text-xs text-n-slate-10">
              {{
                t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.AUTH_CODE_EXPIRATION', {
                  minutes: draft.authentication.code_expiration_minutes,
                })
              }}
            </p>
            <time
              class="justify-self-end text-xs text-n-slate-10"
              data-testid="preview-timestamp"
            >
              {{ previewTime }}
            </time>
          </div>
          <div
            class="border-t border-n-weak px-4 py-3 text-center text-sm font-medium text-n-brand"
          >
            {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.COPY_CODE') }}
          </div>
        </template>

        <template v-else>
          <template
            v-if="
              !['catalog', 'order_details'].includes(draft.model) &&
              ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(draft.header.format)
            "
          >
            <div
              v-if="draft.header.format === 'IMAGE'"
              class="m-2 mb-0 aspect-video overflow-hidden rounded-lg bg-n-alpha-2"
            >
              <img
                v-if="draft.header.media_preview_url"
                :src="draft.header.media_preview_url"
                alt=""
                class="size-full object-cover"
              />
              <div
                v-else
                class="grid size-full place-content-center text-n-slate-10"
              >
                <i class="i-lucide-image size-8" />
              </div>
            </div>
            <div
              v-else-if="
                draft.header.format === 'VIDEO' &&
                draft.header.media_preview_url
              "
              class="m-2 mb-0 overflow-hidden rounded-lg bg-n-alpha-2"
            >
              <video
                :src="draft.header.media_preview_url"
                class="aspect-video w-full object-cover"
                controls
                preload="metadata"
              />
            </div>
            <div
              v-else-if="draft.header.format === 'VIDEO'"
              class="m-2 mb-0 grid aspect-video place-content-center rounded-lg bg-n-alpha-2 text-n-slate-10"
            >
              <i class="i-lucide-video size-8" />
            </div>
            <div
              v-else
              class="m-2 mb-0 flex items-center gap-3 rounded-lg bg-n-alpha-2 p-3"
            >
              <i class="i-lucide-file-text size-7 text-n-slate-10" />
              <span class="min-w-0 truncate text-sm text-n-slate-12">
                {{
                  draft.header.media_filename ||
                  t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.MEDIA')
                }}
              </span>
            </div>
          </template>

          <template v-if="draft.model === 'catalog'">
            <div
              class="m-2 mb-0 grid grid-cols-[5.5rem_minmax(0,1fr)] overflow-hidden rounded-lg bg-n-alpha-2"
              data-testid="preview-catalog-card"
            >
              <div class="grid min-h-24 place-content-center bg-n-alpha-2">
                <i class="i-lucide-shopping-basket size-9 text-n-brand" />
              </div>
              <div class="grid content-center gap-1 p-3">
                <strong class="text-sm font-semibold text-n-slate-12">
                  {{
                    t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.CATALOG_CARD_TITLE')
                  }}
                </strong>
                <span class="text-xs text-n-slate-10">
                  {{
                    t(
                      'IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.CATALOG_CARD_DESCRIPTION'
                    )
                  }}
                </span>
              </div>
            </div>
            <div class="grid gap-2 p-3">
              <p class="m-0 whitespace-pre-wrap text-sm text-n-slate-12">
                {{ messageBody }}
              </p>
              <p v-if="draft.footer.text" class="m-0 text-xs text-n-slate-10">
                {{ draft.footer.text }}
              </p>
              <time
                class="justify-self-end text-xs text-n-slate-10"
                data-testid="preview-timestamp"
              >
                {{ previewTime }}
              </time>
            </div>
          </template>

          <template v-else-if="draft.model === 'order_details'">
            <div
              class="m-2 mb-0 overflow-hidden rounded-lg bg-n-alpha-2"
              data-testid="preview-order-details"
            >
              <div
                class="border-b border-n-weak px-3 py-2 text-xs font-semibold uppercase text-n-slate-11"
              >
                {{ orderReference }}
              </div>
              <div
                v-if="draft.header.format === 'IMAGE'"
                class="aspect-video bg-n-alpha-2"
              >
                <img
                  v-if="draft.header.media_preview_url"
                  :src="draft.header.media_preview_url"
                  alt=""
                  class="size-full object-cover"
                />
                <div
                  v-else
                  class="grid size-full place-content-center text-n-slate-10"
                >
                  <i class="i-lucide-image size-8" />
                </div>
              </div>
              <div
                v-else-if="draft.header.format === 'DOCUMENT'"
                class="flex items-center gap-3 border-b border-n-weak p-3"
              >
                <span
                  class="grid size-10 shrink-0 place-content-center rounded-md bg-n-solid-2 text-n-brand"
                >
                  <i class="i-lucide-file-text size-6" />
                </span>
                <span class="min-w-0 truncate text-sm font-medium">
                  {{
                    draft.header.media_filename ||
                    t(
                      'IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ORDER_DOCUMENT_NAME'
                    )
                  }}
                </span>
              </div>
              <div
                class="flex items-center justify-between gap-3 border-b border-n-weak px-3 py-2.5"
              >
                <span class="text-sm text-n-slate-11">
                  {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.PAYMENT_METHOD') }}
                </span>
                <span class="flex items-center gap-1.5">
                  <span
                    class="grid size-7 place-content-center rounded-md bg-n-solid-2 text-n-slate-11"
                  >
                    <i class="i-lucide-barcode size-4" />
                  </span>
                  <span
                    class="grid size-7 place-content-center rounded-md bg-n-solid-2 text-n-slate-11"
                  >
                    <i class="i-lucide-credit-card size-4" />
                  </span>
                </span>
              </div>
              <div
                class="flex items-center justify-between gap-3 px-3 py-2.5 text-sm"
              >
                <span class="text-n-slate-11">
                  {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ORDER_TOTAL') }}
                </span>
                <strong class="font-semibold text-n-slate-12">
                  {{
                    t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ORDER_TOTAL_VALUE')
                  }}
                </strong>
              </div>
            </div>
            <div class="grid gap-2 p-3">
              <p class="m-0 whitespace-pre-wrap text-sm text-n-slate-12">
                {{ messageBody }}
              </p>
              <p v-if="draft.footer.text" class="m-0 text-xs text-n-slate-10">
                {{ draft.footer.text }}
              </p>
              <time
                class="justify-self-end text-xs text-n-slate-10"
                data-testid="preview-timestamp"
              >
                {{ previewTime }}
              </time>
            </div>
          </template>

          <template v-else-if="draft.model === 'call_permission_request'">
            <div
              class="m-2 mb-0 flex gap-3 rounded-lg bg-n-alpha-2 p-3"
              data-testid="preview-call-permission"
            >
              <span
                class="grid size-10 shrink-0 place-content-center rounded-full bg-n-solid-2 text-n-slate-12"
              >
                <i class="i-lucide-phone size-5" />
              </span>
              <div class="grid min-w-0 flex-1 gap-1">
                <strong class="text-sm font-semibold text-n-slate-12">
                  {{
                    previewHeader ||
                    t(
                      'IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.CALL_PERMISSION_TITLE'
                    )
                  }}
                </strong>
                <p class="m-0 whitespace-pre-wrap text-sm text-n-slate-11">
                  {{ messageBody }}
                </p>
                <time
                  class="justify-self-end text-xs text-n-slate-10"
                  data-testid="preview-timestamp"
                >
                  {{ previewTime }}
                </time>
              </div>
            </div>
            <p
              v-if="draft.footer.text"
              class="m-0 px-3 pb-3 pt-2 text-xs text-n-slate-10"
            >
              {{ draft.footer.text }}
            </p>
          </template>

          <div v-else class="grid gap-2 p-3">
            <strong
              v-if="draft.model === 'order_status'"
              class="text-sm font-semibold text-n-slate-12"
              data-testid="preview-order-status"
            >
              {{ t('IBSOFT_META_TEMPLATES.EDITOR.PREVIEW.ORDER_STATUS') }}
            </strong>
            <strong
              v-else-if="draft.header.format === 'TEXT' && previewHeader"
              class="text-sm font-semibold text-n-slate-12"
            >
              {{ previewHeader }}
            </strong>
            <p class="m-0 whitespace-pre-wrap text-sm text-n-slate-12">
              {{ messageBody }}
            </p>
            <p v-if="draft.footer.text" class="m-0 text-xs text-n-slate-10">
              {{ draft.footer.text }}
            </p>
            <time
              class="justify-self-end text-xs text-n-slate-10"
              data-testid="preview-timestamp"
            >
              {{ previewTime }}
            </time>
          </div>

          <div
            v-for="(button, index) in previewButtons"
            :key="index"
            class="flex items-center justify-center gap-2 border-t border-n-weak px-4 py-3 text-center text-sm font-medium text-n-brand"
            data-testid="preview-action"
          >
            <i
              class="size-4"
              :class="[
                button.type === 'PHONE_NUMBER'
                  ? 'i-lucide-phone'
                  : button.type === 'URL'
                    ? 'i-lucide-external-link'
                    : 'i-lucide-reply',
              ]"
            />
            {{ button.text }}
          </div>

          <template v-if="draft.model === 'order_details'">
            <div
              v-for="action in orderActions"
              :key="action.text"
              class="flex items-center justify-center gap-2 border-t border-n-weak px-4 py-3 text-center text-sm font-medium text-n-brand"
              data-testid="preview-order-action"
            >
              <i class="size-4" :class="action.icon" />
              {{ action.text }}
            </div>
          </template>

          <div
            v-if="specialAction"
            class="flex items-center justify-center gap-2 border-t border-n-weak px-4 py-3 text-center text-sm font-medium"
            :class="specialAction.className"
            data-testid="preview-special-action"
          >
            <i class="size-4" :class="specialAction.icon" />
            {{ specialAction.text }}
          </div>
        </template>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.whatsapp-preview-canvas::before {
  position: absolute;
  inset: 0;
  content: '';
  background-color: currentColor;
  opacity: 0.08;
  mask-image: url('../assets/whatsapp-preview-pattern.svg');
  mask-repeat: repeat;
  mask-size: 11.25rem 11.25rem;
  -webkit-mask-image: url('../assets/whatsapp-preview-pattern.svg');
  -webkit-mask-repeat: repeat;
  -webkit-mask-size: 11.25rem 11.25rem;
}
</style>
