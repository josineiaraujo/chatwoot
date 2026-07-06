<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';

import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const isLoading = ref(false);
const hasError = ref(false);
const payload = ref({
  summary: { total: 0, by_event_type: {}, by_reason: {} },
  pagination: { page: 1, limit: 25, total_count: 0, total_pages: 1 },
  events: [],
});
const filters = ref({
  eventType: '',
  reason: '',
  conversationId: '',
  inboxId: '',
  teamId: '',
  since: '',
  until: '',
  page: 1,
  limit: 25,
});

const headers = computed(() => [
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.CREATED_AT'),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.EVENT_TYPE'),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.REASON'),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.CONVERSATION'),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.ROUTING'),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TABLE.ASSIGNEES'),
]);

const events = computed(() => payload.value.events || []);
const summary = computed(() => payload.value.summary || {});
const pagination = computed(() => payload.value.pagination || {});
const generatedAt = computed(() => payload.value.generated_at);
const paginationStart = computed(() => {
  const total = pagination.value.total_count || 0;
  if (!total) return 0;

  return (
    ((pagination.value.page || 1) - 1) * (pagination.value.limit || 25) + 1
  );
});
const paginationEnd = computed(() => {
  const total = pagination.value.total_count || 0;
  const page = pagination.value.page || 1;
  const limit = pagination.value.limit || 25;

  return Math.min(page * limit, total);
});

const eventTypeLabels = computed(() => ({
  assignment_completed: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.ASSIGNMENT_COMPLETED'
  ),
  assignment_skipped: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.ASSIGNMENT_SKIPPED'
  ),
  redistribution_completed: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.REDISTRIBUTION_COMPLETED'
  ),
  redistribution_skipped: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.REDISTRIBUTION_SKIPPED'
  ),
  agent_claim_completed: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.AGENT_CLAIM_COMPLETED'
  ),
  agent_claim_skipped: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EVENT_TYPES.AGENT_CLAIM_SKIPPED'
  ),
}));

const reasonLabels = computed(() => ({
  eligible_for_assignment: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.ELIGIBLE_FOR_ASSIGNMENT'
  ),
  real_assignment_disabled: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.REAL_ASSIGNMENT_DISABLED'
  ),
  no_available_agent: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.NO_AVAILABLE_AGENT'
  ),
  candidate_already_claimed: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.CANDIDATE_ALREADY_CLAIMED'
  ),
  candidate_already_changed: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.CANDIDATE_ALREADY_CHANGED'
  ),
  not_available_for_agent: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.NOT_AVAILABLE_FOR_AGENT'
  ),
  first_response_timeout: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.FIRST_RESPONSE_TIMEOUT'
  ),
  outside_business_hours: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.OUTSIDE_BUSINESS_HOURS'
  ),
  not_eligible: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.NOT_ELIGIBLE'
  ),
  conversation_not_found: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.CONVERSATION_NOT_FOUND'
  ),
  required_assignments_missing: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REASONS.REQUIRED_ASSIGNMENTS_MISSING'
  ),
}));

const eventTypeOptions = computed(() => [
  {
    value: '',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.ALL_EVENT_TYPES'
    ),
  },
  ...Object.entries(eventTypeLabels.value).map(([value, label]) => ({
    value,
    label,
  })),
]);

const reasonOptions = computed(() => [
  {
    value: '',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.ALL_REASONS'
    ),
  },
  ...Object.entries(reasonLabels.value).map(([value, label]) => ({
    value,
    label,
  })),
]);

const sortedResourceOptions = resources =>
  [...resources]
    .filter(resource => resource?.id)
    .sort((first, second) =>
      String(first.name || '').localeCompare(String(second.name || ''))
    )
    .map(resource => ({
      value: String(resource.id),
      label: resource.name,
    }));

const inboxOptions = computed(() => [
  {
    value: '',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.ALL_INBOXES'
    ),
  },
  ...sortedResourceOptions(store.getters['inboxes/getInboxes'] || []),
]);

const teamOptions = computed(() => [
  {
    value: '',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.ALL_TEAMS'
    ),
  },
  ...sortedResourceOptions(store.getters['teams/getTeams'] || []),
]);

const eventTypeLabel = value => eventTypeLabels.value[value] || value;
const emptyValue = () =>
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EMPTY_VALUE');
const reasonLabel = value =>
  value ? reasonLabels.value[value] || value : emptyValue();

const contactName = event => {
  const contact = event.conversation?.contact;
  return (
    contact?.name || contact?.email || contact?.phone_number || emptyValue()
  );
};

const buildParams = () => ({
  event_type: filters.value.eventType || undefined,
  reason: filters.value.reason || undefined,
  conversation_id: filters.value.conversationId || undefined,
  inbox_id: filters.value.inboxId || undefined,
  team_id: filters.value.teamId || undefined,
  since: filters.value.since || undefined,
  until: filters.value.until || undefined,
  page: filters.value.page,
  limit: filters.value.limit,
});

const formatDateTime = value => {
  if (!value) return emptyValue();

  return new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const fetchEvents = async () => {
  isLoading.value = true;
  hasError.value = false;

  try {
    const { data } =
      await conversationDistributionAPI.getEventLogs(buildParams());
    payload.value = data;
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const loadFilterOptions = () => {
  Promise.allSettled([
    store.dispatch('inboxes/get'),
    store.dispatch('teams/get'),
  ]);
};

const applyFilters = () => {
  filters.value.page = 1;
  fetchEvents();
};

const clearFilters = () => {
  filters.value = {
    eventType: '',
    reason: '',
    conversationId: '',
    inboxId: '',
    teamId: '',
    since: '',
    until: '',
    page: 1,
    limit: filters.value.limit,
  };
  fetchEvents();
};

const goToPage = page => {
  filters.value.page = page;
  fetchEvents();
};

const openSupervisor = () => {
  router.push({
    name: 'ibsoft_conversation_distribution_supervisor',
    params: { accountId: route.params.accountId },
  });
};

const conversationHref = event => {
  if (!event.conversation?.display_id) return null;

  return frontendURL(
    conversationUrl({
      accountId: route.params.accountId,
      id: event.conversation.display_id,
    })
  );
};

onMounted(() => {
  loadFilterOptions();
  fetchEvents();
});
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full max-w-none flex-col overflow-auto bg-n-background p-6 text-n-slate-12"
  >
    <header
      class="flex flex-col gap-4 border-b border-n-weak pb-5 md:flex-row md:items-start md:justify-between"
    >
      <div class="min-w-0">
        <h1 class="mb-1 text-heading-1 text-n-slate-12">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.TITLE') }}
        </h1>
        <p class="mb-0 max-w-3xl text-body-main text-n-slate-11">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.DESCRIPTION')
          }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          :label="
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.BACK_TO_SUPERVISION'
            )
          "
          icon="i-lucide-arrow-left"
          faded
          size="sm"
          @click="openSupervisor"
        />
        <Button
          :label="
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.REFRESH')
          "
          icon="i-lucide-refresh-cw"
          faded
          size="sm"
          :is-loading="isLoading"
          @click="fetchEvents"
        />
      </div>
    </header>

    <section class="grid gap-3 py-5 md:grid-cols-3">
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.SUMMARY.TOTAL')
          }}
        </p>
        <strong class="text-heading-1 text-n-slate-12">
          {{ summary.total || 0 }}
        </strong>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.SUMMARY.PAGE')
          }}
        </p>
        <strong class="text-heading-3 text-n-slate-12">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.PAGINATION.PAGE',
              {
                page: pagination.page || 1,
                total: pagination.total_pages || 1,
              }
            )
          }}
        </strong>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.SUMMARY.UPDATED'
            )
          }}
        </p>
        <strong class="text-heading-3 text-n-slate-12">
          {{ formatDateTime(generatedAt) }}
        </strong>
      </div>
    </section>

    <section
      class="mb-4 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      @keyup.enter="applyFilters"
    >
      <div class="grid gap-3 md:grid-cols-4">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.EVENT_TYPE'
              )
            }}
          </span>
          <IbsoftSelect v-model="filters.eventType">
            <option
              v-for="option in eventTypeOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.REASON'
              )
            }}
          </span>
          <IbsoftSelect v-model="filters.reason">
            <option
              v-for="option in reasonOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.CONVERSATION'
              )
            }}
          </span>
          <input
            v-model="filters.conversationId"
            type="text"
            inputmode="numeric"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.INBOX'
              )
            }}
          </span>
          <IbsoftSelect v-model="filters.inboxId">
            <option
              v-for="option in inboxOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.TEAM'
              )
            }}
          </span>
          <IbsoftSelect v-model="filters.teamId">
            <option
              v-for="option in teamOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.SINCE'
              )
            }}
          </span>
          <input
            v-model="filters.since"
            type="datetime-local"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.UNTIL'
              )
            }}
          </span>
          <input
            v-model="filters.until"
            type="datetime-local"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          />
        </label>

        <div class="flex items-end gap-2">
          <Button
            :label="
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.APPLY'
              )
            "
            size="sm"
            @click="applyFilters"
          />
          <Button
            :label="
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.FILTERS.CLEAR'
              )
            "
            size="sm"
            faded
            @click="clearFilters"
          />
        </div>
      </div>
    </section>

    <section
      class="flex min-h-[32rem] flex-1 flex-col overflow-hidden rounded-lg border border-n-weak bg-n-alpha-1"
    >
      <div v-if="isLoading" class="grid min-h-0 flex-1 place-content-center">
        <Spinner />
      </div>

      <div
        v-else-if="hasError"
        class="grid min-h-0 flex-1 place-content-center p-6 text-center text-body-main text-n-ruby-11"
      >
        {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.API_ERROR') }}
      </div>

      <template v-else>
        <div class="min-h-0 flex-1 overflow-auto px-4">
          <BaseTable
            :headers="headers"
            :items="events"
            :no-data-message="
              t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.EMPTY')
            "
          >
            <template #row="{ items }">
              <BaseTableRow
                v-for="event in items"
                :key="event.id"
                :item="event"
              >
                <BaseTableCell>
                  <p class="mb-0 whitespace-nowrap text-n-slate-12">
                    {{ formatDateTime(event.created_at) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 text-n-slate-12">
                    {{ eventTypeLabel(event.event_type) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 text-n-slate-12">
                    {{ reasonLabel(event.reason) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <a
                    v-if="event.conversation?.display_id"
                    :href="conversationHref(event)"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-start text-n-blue-11 hover:underline"
                  >
                    {{
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.CONVERSATION_ID',
                        { id: event.conversation.display_id }
                      )
                    }}
                  </a>
                  <span v-else class="text-n-slate-11">{{ emptyValue() }}</span>
                  <p
                    class="mb-0 max-w-48 truncate text-label-small text-n-slate-11"
                  >
                    {{ contactName(event) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 max-w-48 truncate text-n-slate-12">
                    {{ event.team?.name || emptyValue() }}
                  </p>
                  <p
                    class="mb-0 max-w-48 truncate text-label-small text-n-slate-11"
                  >
                    {{ event.inbox?.name || emptyValue() }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 max-w-48 truncate text-n-slate-12">
                    {{ event.previous_assignee?.name || emptyValue() }}
                  </p>
                  <p
                    class="mb-0 max-w-48 truncate text-label-small text-n-slate-11"
                  >
                    {{ event.new_assignee?.name || emptyValue() }}
                  </p>
                </BaseTableCell>
              </BaseTableRow>
            </template>
          </BaseTable>
        </div>

        <footer
          class="flex shrink-0 flex-col gap-3 border-t border-n-weak bg-n-alpha-1 px-4 py-3 md:flex-row md:items-center md:justify-between"
        >
          <span class="text-body-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.PAGINATION.RESULTS',
                {
                  start: paginationStart,
                  end: paginationEnd,
                  total: pagination.total_count || 0,
                }
              )
            }}
          </span>
          <div class="flex items-center justify-between gap-3 md:justify-end">
            <Button
              :label="
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.PAGINATION.PREVIOUS'
                )
              "
              faded
              size="sm"
              :disabled="!pagination.previous_page"
              @click="goToPage(pagination.previous_page)"
            />
            <span class="text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.PAGINATION.PAGE',
                  {
                    page: pagination.page || 1,
                    total: pagination.total_pages || 1,
                  }
                )
              }}
            </span>
            <Button
              :label="
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.EVENT_LOGS.PAGINATION.NEXT'
                )
              "
              faded
              size="sm"
              :disabled="!pagination.next_page"
              @click="goToPage(pagination.next_page)"
            />
          </div>
        </footer>
      </template>
    </section>
  </main>
</template>
