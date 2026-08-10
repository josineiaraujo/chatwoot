<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import InstanceTypeMark from './InstanceTypeMark.vue';

defineProps({
  endpoint: {
    type: Object,
    required: true,
  },
  typeDefinition: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['view', 'edit', 'credentials', 'toggle']);
</script>

<template>
  <article
    class="flex min-h-60 min-w-0 flex-col rounded-lg border border-n-weak bg-n-alpha-1 p-4"
  >
    <div class="flex min-w-0 items-start justify-between gap-3">
      <div
        class="grid h-10 w-20 shrink-0 place-content-center rounded-lg bg-n-alpha-2 px-2 text-n-slate-12"
      >
        <InstanceTypeMark
          :type-definition="typeDefinition"
          image-class="max-h-7 max-w-16"
        />
      </div>
      <span
        class="inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-label-small"
        :class="
          endpoint.active
            ? 'bg-n-teal-3 text-n-teal-11'
            : 'bg-n-alpha-2 text-n-slate-11'
        "
      >
        <span
          class="size-1.5 rounded-full"
          :class="endpoint.active ? 'bg-n-teal-9' : 'bg-n-slate-9'"
        />
        {{
          endpoint.active
            ? $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVE')
            : $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.INACTIVE')
        }}
      </span>
    </div>

    <div class="mt-5 min-w-0">
      <h3 class="mb-0 truncate text-heading-2 text-n-slate-12">
        {{ endpoint.name }}
      </h3>
      <p
        class="mb-0 mt-2 inline-flex max-w-full truncate rounded-md bg-n-alpha-2 px-2 py-1 text-label-small text-n-slate-11"
      >
        {{ typeDefinition.label }}
      </p>
    </div>

    <div
      class="mt-4 flex min-w-0 items-center gap-3 rounded-lg bg-n-alpha-2 px-3 py-3"
    >
      <span
        class="grid size-8 shrink-0 place-content-center rounded-md bg-n-teal-3 text-n-teal-11"
      >
        <i class="i-ri-whatsapp-fill size-4" />
      </span>
      <div class="min-w-0">
        <span class="block text-label-small text-n-slate-11">
          {{ $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CHANNEL') }}
        </span>
        <span class="mt-0.5 block truncate text-sm font-medium text-n-slate-12">
          {{ endpoint.inbox_name }}
        </span>
      </div>
    </div>

    <dl class="mt-4 grid grid-cols-2 border-t border-n-weak py-3">
      <div class="min-w-0 pr-4">
        <dt class="text-label-small text-n-slate-11">
          {{ $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.REQUESTS') }}
        </dt>
        <dd class="mt-1 truncate text-heading-3 text-n-slate-12">
          {{ endpoint.deliveries_count }}
        </dd>
      </div>
      <div class="min-w-0 border-l border-n-weak pl-4">
        <dt class="text-label-small text-n-slate-11">
          {{ $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RATE_SHORT') }}
        </dt>
        <dd class="mt-1 truncate text-heading-3 text-n-slate-12">
          {{
            $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.RATE_CARD_VALUE', {
              count: endpoint.rate_limit_per_second,
            })
          }}
        </dd>
      </div>
    </dl>

    <div
      class="mt-auto flex items-center justify-between gap-2 border-t border-n-weak pt-3"
    >
      <Button
        :label="$t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.VIEW')"
        icon="i-lucide-eye"
        size="sm"
        color="slate"
        variant="faded"
        @click="emit('view', endpoint)"
      />
      <div class="flex items-center gap-1">
        <Button
          v-tooltip.top="$t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EDIT')"
          icon="i-lucide-pencil"
          size="sm"
          color="slate"
          variant="ghost"
          :aria-label="$t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EDIT')"
          @click="emit('edit', endpoint)"
        />
        <Button
          v-tooltip.top="$t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREDENTIALS')"
          icon="i-lucide-key-round"
          size="sm"
          color="slate"
          variant="ghost"
          :aria-label="$t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.CREDENTIALS')"
          @click="emit('credentials', endpoint)"
        />
        <Button
          v-tooltip.top="
            endpoint.active
              ? $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.DEACTIVATE')
              : $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVATE')
          "
          :icon="
            endpoint.active ? 'i-lucide-circle-pause' : 'i-lucide-circle-play'
          "
          size="sm"
          :color="endpoint.active ? 'ruby' : 'teal'"
          variant="ghost"
          :aria-label="
            endpoint.active
              ? $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.DEACTIVATE')
              : $t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.ACTIVATE')
          "
          @click="emit('toggle', endpoint)"
        />
      </div>
    </div>
  </article>
</template>
