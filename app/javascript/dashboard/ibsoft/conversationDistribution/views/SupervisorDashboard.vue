<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const isLoading = ref(false);
const hasError = ref(false);
const payload = ref({
  summary: { scanned: 0, alerts: 0, by_reason: {}, by_severity: {} },
  alerts: [],
});
const filters = ref({
  reason: 'all',
  severity: 'all',
  teamId: 'all',
  inboxId: 'all',
});

const headers = computed(() => [
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.CONVERSATION'
  ),
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.CUSTOMER'
  ),
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.ROUTING'
  ),
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.WAITING'
  ),
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.SEVERITY'
  ),
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TABLE.REASON'),
  '',
]);

const alerts = computed(() => payload.value.alerts || []);
const filteredAlerts = computed(() =>
  alerts.value.filter(alert => {
    const matchesReason =
      filters.value.reason === 'all' || alert.reason === filters.value.reason;
    const matchesSeverity =
      filters.value.severity === 'all' ||
      alert.severity === filters.value.severity;
    const matchesTeam =
      filters.value.teamId === 'all' ||
      String(alert.team?.id) === filters.value.teamId;
    const matchesInbox =
      filters.value.inboxId === 'all' ||
      String(alert.inbox?.id) === filters.value.inboxId;

    return matchesReason && matchesSeverity && matchesTeam && matchesInbox;
  })
);
const visibleAlertsCount = computed(() => filteredAlerts.value.length);
const summary = computed(() => payload.value.summary || {});
const generatedAt = computed(() => payload.value.generated_at);
const criticalAlerts = computed(() => summary.value.by_severity?.critical || 0);

const uniqueResourceOptions = (resourceKey, allLabel) => {
  const options = new Map();
  alerts.value.forEach(alert => {
    const resource = alert[resourceKey];
    if (resource?.id) {
      options.set(String(resource.id), resource.name);
    }
  });

  return [
    {
      value: 'all',
      label: allLabel,
    },
    ...[...options.entries()].map(([value, label]) => ({ value, label })),
  ];
};

const teamOptions = computed(() =>
  uniqueResourceOptions(
    'team',
    t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.ALL_TEAMS'
    )
  )
);

const inboxOptions = computed(() =>
  uniqueResourceOptions(
    'inbox',
    t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.ALL_INBOXES'
    )
  )
);

const reasonLabels = computed(() => ({
  unassigned_waiting: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.REASONS.UNASSIGNED'
  ),
  assigned_without_first_reply: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.REASONS.ASSIGNED'
  ),
}));

const reasonLabel = reason =>
  reasonLabels.value[reason] || reasonLabels.value.unassigned_waiting;

const reasonOptions = computed(() => [
  {
    value: 'all',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.ALL_REASONS'
    ),
  },
  { value: 'unassigned_waiting', label: reasonLabel('unassigned_waiting') },
  {
    value: 'assigned_without_first_reply',
    label: reasonLabel('assigned_without_first_reply'),
  },
]);

const severityLabels = computed(() => ({
  warning: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SEVERITY.WARNING'
  ),
  critical: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SEVERITY.CRITICAL'
  ),
}));

const severityLabel = severity =>
  severityLabels.value[severity] || severityLabels.value.warning;

const severityOptions = computed(() => [
  {
    value: 'all',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.ALL_SEVERITIES'
    ),
  },
  { value: 'warning', label: severityLabel('warning') },
  { value: 'critical', label: severityLabel('critical') },
]);

const severityClass = severity =>
  severity === 'critical'
    ? 'bg-n-ruby-3 text-n-ruby-11 ring-n-ruby-6'
    : 'bg-n-amber-3 text-n-amber-11 ring-n-amber-6';

const resourceName = resource =>
  resource?.name ||
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.EMPTY_VALUE');

const contactName = alert =>
  alert.contact?.name ||
  alert.contact?.email ||
  alert.contact?.phone_number ||
  t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.UNKNOWN_CUSTOMER'
  );

const formatDateTime = value => {
  if (!value) {
    return t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.EMPTY_VALUE'
    );
  }

  return new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

const fetchAlerts = async () => {
  isLoading.value = true;
  hasError.value = false;

  try {
    const { data } = await conversationDistributionAPI.getSupervisorAlerts({
      limit: 100,
    });
    payload.value = data;
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const openConversation = alert => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: alert.display_id,
    },
  });
};

const openEventLogs = () => {
  router.push({
    name: 'ibsoft_conversation_distribution_event_logs',
    params: { accountId: route.params.accountId },
  });
};

const openChathubHome = () => {
  router.push({
    name: 'ibsoft_chathub_home',
    params: { accountId: route.params.accountId },
  });
};

onMounted(fetchAlerts);
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
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.TITLE'
            )
          }}
        </h1>
        <p class="mb-0 max-w-3xl text-body-main text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.DESCRIPTION'
            )
          }}
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-2">
        <Button
          :label="
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.BACK_TO_HOME'
            )
          "
          icon="i-lucide-arrow-left"
          faded
          size="sm"
          @click="openChathubHome"
        />
        <Button
          :label="
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.EVENT_LOGS'
            )
          "
          icon="i-lucide-list-checks"
          faded
          size="sm"
          @click="openEventLogs"
        />
        <Button
          :label="
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.REFRESH'
            )
          "
          icon="i-lucide-refresh-cw"
          faded
          size="sm"
          :is-loading="isLoading"
          @click="fetchAlerts"
        />
      </div>
    </header>

    <section class="grid gap-3 py-5 md:grid-cols-4">
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SUMMARY.ALERTS'
            )
          }}
        </p>
        <strong class="text-heading-1 text-n-slate-12">{{
          summary.alerts || 0
        }}</strong>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SUMMARY.SCANNED'
            )
          }}
        </p>
        <strong class="text-heading-1 text-n-slate-12">{{
          summary.scanned || 0
        }}</strong>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SUMMARY.CRITICAL'
            )
          }}
        </p>
        <strong class="text-heading-1 text-n-slate-12">{{
          criticalAlerts
        }}</strong>
      </div>
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <p class="mb-1 text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.SUMMARY.UPDATED'
            )
          }}
        </p>
        <strong class="text-heading-3 text-n-slate-12">
          {{ formatDateTime(generatedAt) }}
        </strong>
      </div>
    </section>

    <section class="mb-4 rounded-lg border border-n-weak bg-n-alpha-1 p-4">
      <div class="grid gap-3 md:grid-cols-4">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.REASON'
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
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.SEVERITY'
              )
            }}
          </span>
          <IbsoftSelect v-model="filters.severity">
            <option
              v-for="option in severityOptions"
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
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.TEAM'
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
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.FILTERS.INBOX'
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
      </div>
    </section>

    <section
      class="flex min-h-[30rem] flex-1 flex-col overflow-hidden rounded-lg border border-n-weak bg-n-alpha-1"
    >
      <div v-if="isLoading" class="grid min-h-0 flex-1 place-content-center">
        <Spinner />
      </div>

      <div
        v-else-if="hasError"
        class="grid min-h-0 flex-1 place-content-center p-6 text-center text-body-main text-n-ruby-11"
      >
        {{
          t(
            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.API_ERROR'
          )
        }}
      </div>

      <template v-else>
        <div class="min-h-0 flex-1 overflow-auto px-4">
          <BaseTable
            :headers="headers"
            :items="filteredAlerts"
            :no-data-message="
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.EMPTY'
              )
            "
          >
            <template #row="{ items }">
              <BaseTableRow
                v-for="alert in items"
                :key="alert.conversation_id"
                :item="alert"
              >
                <BaseTableCell>
                  <div class="min-w-0">
                    <p class="mb-0 font-medium text-n-slate-12">
                      {{
                        t(
                          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.CONVERSATION_ID',
                          { id: alert.display_id }
                        )
                      }}
                    </p>
                    <p class="mb-0 text-label-small text-n-slate-11">
                      {{ formatDateTime(alert.last_activity_at) }}
                    </p>
                  </div>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 max-w-52 truncate text-n-slate-12">
                    {{ contactName(alert) }}
                  </p>
                  <p
                    class="mb-0 max-w-52 truncate text-label-small text-n-slate-11"
                  >
                    {{
                      alert.contact?.email ||
                      alert.contact?.phone_number ||
                      resourceName(null)
                    }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 text-n-slate-12">
                    {{ resourceName(alert.team) }}
                  </p>
                  <p class="mb-0 text-label-small text-n-slate-11">
                    {{ resourceName(alert.inbox) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 font-medium text-n-slate-12">
                    {{
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.MINUTES',
                        { count: alert.minutes_waiting }
                      )
                    }}
                  </p>
                  <p class="mb-0 text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.THRESHOLD',
                        { count: alert.threshold_minutes }
                      )
                    }}
                  </p>
                </BaseTableCell>
                <BaseTableCell>
                  <span
                    class="inline-flex rounded-full px-2 py-0.5 text-label-small font-medium ring-1"
                    :class="severityClass(alert.severity)"
                  >
                    {{ severityLabel(alert.severity) }}
                  </span>
                </BaseTableCell>
                <BaseTableCell>
                  <p class="mb-0 text-n-slate-12">
                    {{ reasonLabel(alert.reason) }}
                  </p>
                  <p class="mb-0 text-label-small text-n-slate-11">
                    {{ alert.assignee?.name || resourceName(null) }}
                  </p>
                </BaseTableCell>
                <BaseTableCell align="end">
                  <Button
                    :label="
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.OPEN_CONVERSATION'
                      )
                    "
                    size="xs"
                    faded
                    @click="openConversation(alert)"
                  />
                </BaseTableCell>
              </BaseTableRow>
            </template>
          </BaseTable>
        </div>

        <footer
          class="shrink-0 border-t border-n-weak bg-n-alpha-1 px-4 py-3 text-body-small text-n-slate-11"
        >
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_DASHBOARD.VISIBLE_ALERTS',
              { count: visibleAlertsCount }
            )
          }}
        </footer>
      </template>
    </section>
  </main>
</template>
