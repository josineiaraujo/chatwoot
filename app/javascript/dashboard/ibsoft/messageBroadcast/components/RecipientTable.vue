<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import PageSizeSelect from './PageSizeSelect.vue';

const props = defineProps({
  recipients: {
    type: Array,
    default: () => [],
  },
  canContinue: {
    type: Boolean,
    default: false,
  },
  showContinue: {
    type: Boolean,
    default: true,
  },
  emptyMessage: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['continue', 'remove', 'update']);
const { t } = useI18n();

const currentPage = ref(1);
const pageSize = ref(10);
const searchQuery = ref('');
const phoneFilter = ref('all');
const editingRecipientId = ref('');
const editForm = ref({ primaryPhone: '', fallbackPhone: '' });
const editError = ref('');

const phoneFilterOptions = computed(() => [
  {
    value: 'all',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FILTERS.ALL'),
  },
  {
    value: 'deliverable',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FILTERS.DELIVERABLE'),
  },
  {
    value: 'unavailable',
    label: t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FILTERS.UNAVAILABLE'),
  },
]);

const deliverableCount = computed(
  () =>
    props.recipients.filter(recipient => recipient.phone_selection?.deliverable)
      .length
);

const normalizedSearchQuery = computed(() =>
  searchQuery.value.trim().toLocaleLowerCase()
);

const filteredRecipients = computed(() =>
  props.recipients.filter(recipient => {
    const deliverable = Boolean(recipient.phone_selection?.deliverable);
    const matchesPhoneFilter =
      phoneFilter.value === 'all' ||
      (phoneFilter.value === 'deliverable' && deliverable) ||
      (phoneFilter.value === 'unavailable' && !deliverable);
    if (!matchesPhoneFilter) return false;
    if (!normalizedSearchQuery.value) return true;

    return [
      recipient.name,
      recipient.city_name,
      recipient.state,
      recipient.phone_selection?.primary_phone,
      recipient.phone_selection?.fallback_phone,
    ]
      .filter(Boolean)
      .some(value =>
        String(value).toLocaleLowerCase().includes(normalizedSearchQuery.value)
      );
  })
);

const totalPages = computed(() =>
  Math.max(1, Math.ceil(filteredRecipients.value.length / pageSize.value))
);

const paginatedRecipients = computed(() => {
  const offset = (currentPage.value - 1) * pageSize.value;
  return filteredRecipients.value.slice(offset, offset + pageSize.value);
});

const recipientLocation = recipient =>
  [recipient.city_name, recipient.state].filter(Boolean).join(' - ') ||
  t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.UNKNOWN_LOCATION');

const recipientId = recipient => String(recipient.external_id);
const isEditing = recipient =>
  editingRecipientId.value === recipientId(recipient);

const startEditing = recipient => {
  editingRecipientId.value = recipientId(recipient);
  editForm.value = {
    primaryPhone: recipient.phone_selection?.primary_phone || '',
    fallbackPhone: recipient.phone_selection?.fallback_phone || '',
  };
  editError.value = '';
};

const cancelEditing = () => {
  editingRecipientId.value = '';
  editError.value = '';
};

const normalizePhone = value => {
  let digits = String(value || '').replace(/\D/g, '');
  if (!digits) return '';
  if ([10, 11].includes(digits.length)) digits = `55${digits}`;
  if (!digits.startsWith('55') || ![12, 13].includes(digits.length))
    return null;

  return `+${digits}`;
};

const saveEditing = recipient => {
  const primaryPhone = normalizePhone(editForm.value.primaryPhone);
  const fallbackPhone = normalizePhone(editForm.value.fallbackPhone);
  if (primaryPhone === null || fallbackPhone === null) {
    editError.value = t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.INVALID_PHONE'
    );
    return;
  }

  const uniqueFallbackPhone =
    fallbackPhone === primaryPhone ? '' : fallbackPhone;
  emit('update', {
    ...recipient,
    phone_selection: {
      ...recipient.phone_selection,
      primary_phone: primaryPhone,
      fallback_phone: uniqueFallbackPhone,
      deliverable: Boolean(primaryPhone || uniqueFallbackPhone),
      reason: 'manual_override',
    },
  });
  cancelEditing();
};

watch([searchQuery, phoneFilter, pageSize], () => {
  currentPage.value = 1;
});

watch(
  () => props.recipients.length,
  () => {
    currentPage.value = Math.min(currentPage.value, totalPages.value);
  }
);
</script>

<template>
  <section
    data-testid="message-broadcast-recipient-table"
    class="overflow-hidden rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 border-b border-n-weak px-4 py-4"
    >
      <div>
        <h2 class="font-medium text-n-slate-12">
          {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-n-slate-11">
          {{
            t('IBSOFT_THEME.MESSAGE_BROADCAST.REVIEW.SELECTED_COUNT', {
              count: recipients.length,
              deliverable: deliverableCount,
            })
          }}
        </p>
      </div>
      <Button
        v-if="showContinue"
        icon="i-lucide-arrow-right"
        :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.ACTIONS.CONTINUE')"
        :disabled="!canContinue"
        @click="emit('continue')"
      />
    </header>

    <div
      v-if="recipients.length"
      class="grid gap-3 border-b border-n-weak px-4 py-3 md:grid-cols-[minmax(0,1fr)_16rem_auto] md:items-center"
    >
      <Input
        v-model="searchQuery"
        :placeholder="
          t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.SEARCH_PLACEHOLDER')
        "
        custom-input-class="!pl-9"
      >
        <template #prefix>
          <span
            class="pointer-events-none absolute left-3 top-3 i-lucide-search size-4 text-n-slate-10"
          />
        </template>
      </Input>
      <IbsoftSelect v-model="phoneFilter">
        <option
          v-for="option in phoneFilterOptions"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </IbsoftSelect>
      <PageSizeSelect v-model="pageSize" />
    </div>

    <div
      v-if="recipients.length && filteredRecipients.length"
      class="overflow-x-auto"
    >
      <table class="w-full min-w-[48rem] border-collapse text-left text-sm">
        <thead class="bg-n-alpha-1 text-xs font-medium text-n-slate-11">
          <tr>
            <th class="px-4 py-3">
              {{
                t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.COLUMNS.CUSTOMER')
              }}
            </th>
            <th class="px-4 py-3">
              {{
                t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.COLUMNS.PHONES')
              }}
            </th>
            <th class="px-4 py-3">
              {{
                t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.COLUMNS.LOCATION')
              }}
            </th>
            <th class="w-28 px-4 py-3 text-right">
              {{
                t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.COLUMNS.ACTIONS')
              }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-n-weak">
          <tr
            v-for="recipient in paginatedRecipients"
            :key="recipient.external_id"
          >
            <td class="px-4 py-3 align-top">
              <p class="m-0 font-medium text-n-slate-12">
                {{ recipient.name }}
              </p>
              <p class="m-0 text-xs text-n-slate-10">
                {{
                  t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EXTERNAL_ID', {
                    id: recipient.external_id,
                  })
                }}
              </p>
            </td>
            <td class="px-4 py-3 align-top">
              <div v-if="isEditing(recipient)" class="grid gap-2">
                <Input
                  v-model="editForm.primaryPhone"
                  :label="
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.PRIMARY_PHONE'
                    )
                  "
                />
                <Input
                  v-model="editForm.fallbackPhone"
                  :label="
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.FALLBACK_PHONE'
                    )
                  "
                  :message="editError"
                  message-type="error"
                />
              </div>
              <div v-else class="grid gap-1">
                <span class="text-n-slate-12">
                  {{
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.PRIMARY_PHONE_VALUE',
                      {
                        phone:
                          recipient.phone_selection?.primary_phone ||
                          t('IBSOFT_THEME.MESSAGE_BROADCAST.RESULTS.NO_PHONE'),
                      }
                    )
                  }}
                </span>
                <span
                  v-if="recipient.phone_selection?.fallback_phone"
                  class="text-xs text-n-slate-10"
                >
                  {{
                    t(
                      'IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FALLBACK_PHONE_VALUE',
                      {
                        phone: recipient.phone_selection.fallback_phone,
                      }
                    )
                  }}
                </span>
              </div>
            </td>
            <td class="px-4 py-3 align-top text-n-slate-11">
              {{ recipientLocation(recipient) }}
            </td>
            <td class="px-4 py-3 align-top">
              <div class="flex justify-end gap-1">
                <template v-if="isEditing(recipient)">
                  <Button
                    icon="i-lucide-check"
                    variant="ghost"
                    size="sm"
                    :title="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.SAVE')
                    "
                    :aria-label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.SAVE')
                    "
                    @click="saveEditing(recipient)"
                  />
                  <Button
                    icon="i-lucide-x"
                    variant="ghost"
                    size="sm"
                    :title="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.CANCEL')
                    "
                    :aria-label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.CANCEL')
                    "
                    @click="cancelEditing"
                  />
                </template>
                <template v-else>
                  <Button
                    icon="i-lucide-pencil"
                    variant="ghost"
                    size="sm"
                    :title="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.ACTION')
                    "
                    :aria-label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EDIT.ACTION')
                    "
                    @click="startEditing(recipient)"
                  />
                  <Button
                    icon="i-lucide-trash-2"
                    variant="ghost"
                    color="ruby"
                    size="sm"
                    :title="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.REMOVE')
                    "
                    :aria-label="
                      t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.REMOVE')
                    "
                    @click="emit('remove', recipient)"
                  />
                </template>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div
      v-else-if="recipients.length"
      class="px-6 py-10 text-center text-sm text-n-slate-11"
    >
      {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.FILTERED_EMPTY') }}
    </div>

    <div v-else class="px-6 py-10 text-center text-sm text-n-slate-11">
      {{ emptyMessage || t('IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.EMPTY') }}
    </div>

    <PaginationFooter
      v-if="filteredRecipients.length > pageSize"
      class="[&_.bg-n-input-background]:!bg-n-alpha-3 [&_.bg-n-input-background]:!text-n-slate-12 [&_.bg-n-input-background]:outline [&_.bg-n-input-background]:outline-1 [&_.bg-n-input-background]:outline-n-weak"
      :current-page="currentPage"
      :total-items="filteredRecipients.length"
      :items-per-page="pageSize"
      current-page-info="IBSOFT_THEME.MESSAGE_BROADCAST.RECIPIENTS.PAGINATION"
      @update:current-page="currentPage = $event"
    />
  </section>
</template>
