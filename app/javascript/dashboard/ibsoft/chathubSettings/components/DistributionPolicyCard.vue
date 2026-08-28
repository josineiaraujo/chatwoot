<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    default: '',
  },
  enabled: {
    type: Boolean,
    default: false,
  },
  linkedChannelsCount: {
    type: Number,
    default: 0,
  },
  linkedTeamsCount: {
    type: Number,
    default: 0,
  },
  assignmentOrder: {
    type: String,
    default: 'round_robin',
  },
  conversationPriority: {
    type: String,
    default: 'longest_waiting',
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const usageLabel = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.USAGE', {
    channels: props.linkedChannelsCount,
    teams: props.linkedTeamsCount,
  })
);

const statusLabel = computed(() =>
  props.enabled
    ? t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.ENABLED')
    : t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DISABLED')
);
const assignmentOrderLabel = computed(() =>
  props.assignmentOrder === 'balanced'
    ? t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.BALANCED.LABEL'
      )
    : t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.ROUND_ROBIN.LABEL'
      )
);
const conversationPriorityLabel = computed(() =>
  props.conversationPriority === 'earliest_created'
    ? t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.EARLIEST_CREATED.LABEL'
      )
    : t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.LONGEST_WAITING.LABEL'
      )
);

const handleEdit = () => emit('edit', props.id);
const handleDelete = () => emit('delete', props.id);
</script>

<template>
  <CardLayout class="[&>div]:px-5">
    <div class="flex w-full flex-col gap-2">
      <div class="flex w-full items-center justify-between gap-3">
        <div class="flex min-w-0 items-center gap-3">
          <h3 class="line-clamp-1 text-heading-2 text-n-slate-12">
            {{ name }}
          </h3>
          <span
            class="shrink-0 rounded-md bg-n-alpha-2 px-2 py-0.5 text-xs font-medium text-n-slate-11"
          >
            {{ statusLabel }}
          </span>
        </div>

        <div class="flex shrink-0 items-center gap-2">
          <Button
            :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.EDIT')"
            sm
            slate
            link
            class="px-2"
            @click="handleEdit"
          />
          <div class="h-2.5 w-px bg-n-slate-5" />
          <Button icon="i-lucide-trash" sm slate ghost @click="handleDelete" />
        </div>
      </div>

      <div class="flex items-center gap-3 py-1.5">
        <span class="text-body-para text-n-slate-11">
          {{ `${t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.ORDER')}:` }}
          <span class="text-n-slate-12">{{ assignmentOrderLabel }}</span>
        </span>
        <div class="h-3 w-px bg-n-strong" />
        <span class="text-body-para text-n-slate-11">
          {{ `${t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.PRIORITY')}:` }}
          <span class="text-n-slate-12">{{ conversationPriorityLabel }}</span>
        </span>
      </div>

      <div class="flex items-center gap-3 py-1">
        <span class="text-body-para text-n-slate-11">
          {{ usageLabel }}
        </span>
      </div>
    </div>
  </CardLayout>
</template>
