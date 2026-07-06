<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import analyticsAPI from '../api';
import BarList from '../components/BarList.vue';
import MetricCard from '../components/MetricCard.vue';
import SuggestionList from '../components/SuggestionList.vue';
import TrendBars from '../components/TrendBars.vue';

const { t, locale } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const MIN_RATE_SAMPLE_SIZE = 5;

const isLoading = ref(false);
const hasError = ref(false);
const activeTab = ref('agent');
const hasUserSelectedDashboard = ref(false);
const agentDashboard = ref(null);
const supervisorDashboard = ref(null);
const filters = ref({
  period: 'last_7_days',
  since: '',
  until: '',
  inboxId: '',
  teamId: '',
});

const currentAccount = computed(() =>
  store.getters.getCurrentUser?.accounts?.find(
    account => Number(account.id) === Number(route.params.accountId)
  )
);

const canReadSupervisor = computed(
  () =>
    currentAccount.value?.role === 'administrator' ||
    currentAccount.value?.permissions?.includes(
      'ibsoft_conversation_distribution_supervise'
    )
);

const inboxOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.ALL_INBOXES'),
  },
  ...(store.getters['inboxes/getInboxes'] || []).map(inbox => ({
    value: String(inbox.id),
    label: inbox.name,
  })),
]);

const teamOptions = computed(() => [
  {
    value: '',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.ALL_TEAMS'),
  },
  ...(store.getters['teams/getTeams'] || []).map(team => ({
    value: String(team.id),
    label: team.name,
  })),
]);

const periodOptions = computed(() => [
  {
    value: 'last_7_days',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.LAST_7_DAYS'),
  },
  {
    value: 'last_30_days',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.LAST_30_DAYS'),
  },
  {
    value: 'custom',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.CUSTOM'),
  },
]);

const currentDashboard = computed(() =>
  activeTab.value === 'supervisor'
    ? supervisorDashboard.value
    : agentDashboard.value
);

const dashboardTabs = computed(() => [
  {
    key: 'agent',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.TABS.AGENT'),
    icon: 'i-lucide-user',
  },
  {
    key: 'supervisor',
    label: t('IBSOFT_THEME.CHATHUB_ANALYTICS.TABS.SUPERVISOR'),
    icon: 'i-lucide-chart-spline',
  },
]);

const homeDescription = computed(() =>
  canReadSupervisor.value
    ? t('IBSOFT_THEME.CHATHUB_ANALYTICS.HOME.SUPERVISOR_DESCRIPTION')
    : t('IBSOFT_THEME.CHATHUB_ANALYTICS.HOME.AGENT_DESCRIPTION')
);

const supervisorRoute = computed(() => ({
  name: 'ibsoft_conversation_distribution_supervisor',
  params: { accountId: route.params.accountId },
}));

const requestParams = computed(() => ({
  period: filters.value.period,
  since: filters.value.period === 'custom' ? filters.value.since : undefined,
  until: filters.value.period === 'custom' ? filters.value.until : undefined,
  inbox_id: filters.value.inboxId || undefined,
  team_id: filters.value.teamId || undefined,
}));

const isCustomPeriod = computed(() => filters.value.period === 'custom');
const currentLocale = computed(
  () => locale.value?.replace('_', '-') || undefined
);

const formatNumber = (value, options = {}) =>
  new Intl.NumberFormat(currentLocale.value, options).format(
    Number(value || 0)
  );

const pluralCategory = count =>
  new Intl.PluralRules(currentLocale.value).select(Number(count || 0));

const pluralized = (key, count) =>
  t(`${key}.${pluralCategory(count) === 'one' ? 'ONE' : 'OTHER'}`, {
    count: formatNumber(count),
  });

const formatConversationCount = count =>
  pluralized('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.CONVERSATION', count);

const formatOpenCount = count =>
  pluralized('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.OPEN_CONVERSATION', count);

const formatClosedCount = count =>
  pluralized('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.CLOSED_CONVERSATION', count);

const formatRedistributionCount = count =>
  pluralized('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.REDISTRIBUTION', count);

const formatUnassignedCount = count =>
  pluralized(
    'IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.UNASSIGNED_CONVERSATION',
    count
  );

const formatFirstResponseCount = count =>
  pluralized('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.FIRST_RESPONSE', count);

const formatDuration = seconds => {
  const numericSeconds = Number(seconds || 0);
  if (numericSeconds < 60) {
    return t('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.SECONDS', {
      count: formatNumber(numericSeconds, { maximumFractionDigits: 0 }),
    });
  }

  const minutes = numericSeconds / 60;
  if (minutes < 60) {
    return t('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.MINUTES', {
      count: formatNumber(minutes, { maximumFractionDigits: 1 }),
    });
  }

  return t('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.HOURS', {
    count: formatNumber(minutes / 60, { maximumFractionDigits: 1 }),
  });
};

const formatRedistributionRatio = (redistributions, handled) => {
  const redistributionCount = Number(redistributions || 0);
  const handledCount = Number(handled || 0);

  if (!handledCount) {
    return '';
  }

  if (handledCount < MIN_RATE_SAMPLE_SIZE) {
    return t(
      'IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.REDISTRIBUTION_RATIO.LOW_SAMPLE',
      {
        redistributions: formatRedistributionCount(redistributionCount),
        handled: formatConversationCount(handledCount),
      }
    );
  }

  return t('IBSOFT_THEME.CHATHUB_ANALYTICS.UNITS.REDISTRIBUTION_RATIO.VALUE', {
    redistributions: formatRedistributionCount(redistributionCount),
    handled: formatConversationCount(handledCount),
    average: formatNumber(redistributionCount / handledCount, {
      maximumFractionDigits: 1,
    }),
  });
};

const formatDateLabel = value =>
  new Intl.DateTimeFormat(currentLocale.value, {
    day: '2-digit',
    month: 'short',
  }).format(new Date(`${value}T00:00:00`));

const formatHourLabel = hour => `${String(hour).padStart(2, '0')}h`;

const maxValue = (items, key) =>
  Math.max(...items.map(item => Number(item[key] || 0)), 0);

const withPercent = (items, key, mapItem) => {
  const max = maxValue(items, key);
  return items.map(item => ({
    ...mapItem(item),
    percent: max ? (Number(item[key] || 0) / max) * 100 : 0,
  }));
};

const localizedSuggestionPayload = item => {
  const payload = item.payload || {};

  if (item.code === 'reduce_response_time') {
    return {
      average_reply_duration: formatDuration(
        Number(payload.average_reply_minutes || 0) * 60
      ),
    };
  }

  if (item.code === 'slow_first_response') {
    return {
      duration: formatDuration(Number(payload.minutes || 0) * 60),
    };
  }

  if (
    ['review_redistributions', 'redistribution_pressure'].includes(item.code)
  ) {
    return {
      redistributions: formatRedistributionCount(payload.count),
    };
  }

  if (
    ['prioritize_waiting_customers', 'unassigned_backlog'].includes(item.code)
  ) {
    return {
      conversations: formatConversationCount(payload.count),
    };
  }

  return payload;
};

const localizedSuggestions = computed(() =>
  (currentDashboard.value?.suggestions || []).map(item => {
    const payload = localizedSuggestionPayload(item);
    return {
      code: item.code,
      title: t(
        `IBSOFT_THEME.CHATHUB_ANALYTICS.SUGGESTIONS.${item.code.toUpperCase()}.TITLE`,
        payload
      ),
      description: t(
        `IBSOFT_THEME.CHATHUB_ANALYTICS.SUGGESTIONS.${item.code.toUpperCase()}.DESCRIPTION`,
        payload
      ),
    };
  })
);

const agentTeamBars = computed(() =>
  withPercent(
    agentDashboard.value?.by_team || [],
    'average_reply_seconds',
    item => ({
      key: item.team_id || 'none',
      label: item.team_name,
      valueLabel: formatDuration(item.average_reply_seconds),
      caption: t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.TEAM_CAPTION', {
        resolved: formatClosedCount(item.resolved_count),
        redistributions: formatRedistributionCount(
          item.redistributions_away_count
        ),
      }),
    })
  )
);

const agentDailyBars = computed(() =>
  withPercent(
    agentDashboard.value?.daily_response || [],
    'average_reply_seconds',
    item => ({
      key: item.date,
      label: formatDateLabel(item.date),
      valueLabel: formatDuration(item.average_reply_seconds),
    })
  )
);

const topAgentBars = computed(() =>
  withPercent(
    supervisorDashboard.value?.top_agents || [],
    'total_handled',
    item => ({
      key: item.agent_id,
      label: item.agent_name,
      valueLabel: formatNumber(item.total_handled),
      caption: t(
        'IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.TOP_AGENT_CAPTION',
        {
          open: formatOpenCount(item.open_count),
          resolved: formatClosedCount(item.resolved_count),
        }
      ),
    })
  )
);

const redistributionBars = computed(() =>
  withPercent(
    supervisorDashboard.value?.redistribution_ranking || [],
    'redistributions_count',
    item => ({
      key: item.agent_id,
      label: item.agent_name,
      valueLabel: formatNumber(item.redistributions_count),
    })
  )
);

const slowResponseBars = computed(() =>
  withPercent(
    supervisorDashboard.value?.slow_response_ranking || [],
    'average_first_response_seconds',
    item => ({
      key: item.agent_id,
      label: item.agent_name,
      valueLabel: formatDuration(item.average_first_response_seconds),
      caption: t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.RESPONSE_CAPTION', {
        responses: formatFirstResponseCount(item.first_responses_count),
      }),
    })
  )
);

const teamHealthBars = computed(() =>
  withPercent(
    supervisorDashboard.value?.by_team || [],
    'redistributions_count',
    item => ({
      key: item.team_id || 'none',
      label: item.team_name,
      valueLabel: formatNumber(item.redistributions_count),
      caption: t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.TEAM_CAPTION', {
        open: formatOpenCount(item.open_count),
        unassigned: formatUnassignedCount(item.unassigned_count),
        response: formatDuration(item.average_first_response_seconds),
      }),
    })
  )
);

const dailyVolumeBars = computed(() =>
  withPercent(
    supervisorDashboard.value?.daily_volume || [],
    'created_count',
    item => ({
      key: item.date,
      label: formatDateLabel(item.date),
      valueLabel: formatNumber(item.created_count),
    })
  )
);

const heatmapItems = computed(() => {
  const items = supervisorDashboard.value?.hourly_heatmap || [];
  const max = maxValue(items, 'conversations_count');
  return items.map(item => ({
    ...item,
    percent: max ? (Number(item.conversations_count || 0) / max) * 100 : 0,
  }));
});

const fetchDashboard = async () => {
  const dashboardType = activeTab.value;
  isLoading.value = true;
  hasError.value = false;

  try {
    const request =
      dashboardType === 'supervisor'
        ? analyticsAPI.getSupervisorDashboard(requestParams.value)
        : analyticsAPI.getAgentDashboard(requestParams.value);
    const { data } = await request;

    if (dashboardType === 'supervisor') {
      supervisorDashboard.value = data;
    } else {
      agentDashboard.value = data;
    }
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const openSupervisorDashboard = () => {
  router.push(supervisorRoute.value);
};

const selectDashboard = dashboardType => {
  if (activeTab.value === dashboardType) {
    return;
  }

  hasUserSelectedDashboard.value = true;
  activeTab.value = dashboardType;
  fetchDashboard();
};

watch(canReadSupervisor, canRead => {
  if (
    canRead &&
    !hasUserSelectedDashboard.value &&
    activeTab.value === 'agent'
  ) {
    activeTab.value = 'supervisor';
    if (!supervisorDashboard.value) {
      fetchDashboard();
    }
  } else if (!canRead && activeTab.value === 'supervisor') {
    activeTab.value = 'agent';
    if (!agentDashboard.value) {
      fetchDashboard();
    }
  }
});

onMounted(() => {
  store.dispatch('inboxes/get');
  store.dispatch('teams/get');
  if (canReadSupervisor.value) {
    activeTab.value = 'supervisor';
  }
  fetchDashboard();
});
</script>

<template>
  <main
    class="flex h-full min-h-0 w-full flex-col overflow-auto bg-n-background p-6 text-n-slate-12"
  >
    <section
      class="flex flex-col gap-2 border-b border-n-weak pb-3 md:flex-row md:items-center md:justify-between"
    >
      <div>
        <h1 class="mb-1 text-heading-1 text-n-slate-12">
          {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.HOME.TITLE') }}
        </h1>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ homeDescription }}
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <template v-if="canReadSupervisor">
          <Button
            v-for="tab in dashboardTabs"
            :key="tab.key"
            :label="tab.label"
            :icon="tab.icon"
            size="sm"
            :faded="activeTab !== tab.key"
            @click="selectDashboard(tab.key)"
          />
        </template>
        <Button
          v-if="canReadSupervisor"
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.HOME.SUPERVISION')"
          icon="i-lucide-shield-alert"
          slate
          size="sm"
          @click="openSupervisorDashboard"
        />
        <Button
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.REFRESH')"
          icon="i-lucide-refresh-cw"
          faded
          size="sm"
          :is-loading="isLoading"
          @click="fetchDashboard"
        />
      </div>
    </section>

    <section class="mb-5 rounded-lg border border-n-weak bg-n-alpha-1 p-4">
      <div class="grid gap-3 md:grid-cols-5">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.PERIOD') }}
          </span>
          <IbsoftSelect v-model="filters.period">
            <option
              v-for="option in periodOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </IbsoftSelect>
        </label>
        <label v-if="isCustomPeriod" class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.SINCE') }}
          </span>
          <input
            v-model="filters.since"
            type="date"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          />
        </label>
        <label v-if="isCustomPeriod" class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.UNTIL') }}
          </span>
          <input
            v-model="filters.until"
            type="date"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          />
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.INBOX') }}
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
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.TEAM') }}
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
        <div class="flex items-end">
          <Button
            :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.FILTERS.APPLY')"
            size="sm"
            @click="fetchDashboard"
          />
        </div>
      </div>
    </section>

    <div v-if="isLoading" class="grid min-h-[24rem] place-content-center">
      <Spinner />
    </div>
    <div
      v-else-if="hasError"
      class="grid min-h-[24rem] place-content-center text-center text-body-main text-n-ruby-11"
    >
      {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.API_ERROR') }}
    </div>

    <template v-else-if="activeTab === 'agent' && agentDashboard">
      <section class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.CARDS.OPEN_ASSIGNED')"
          :value="formatNumber(agentDashboard.summary.open_assigned)"
          icon="i-lucide-inbox"
        />
        <MetricCard
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.CARDS.AVG_REPLY')"
          :value="formatDuration(agentDashboard.summary.average_reply_seconds)"
          icon="i-lucide-timer"
          tone="warning"
        />
        <MetricCard
          :label="
            t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.CARDS.REDISTRIBUTIONS')
          "
          :value="
            formatNumber(agentDashboard.summary.redistributions_away_count)
          "
          :hint="
            formatRedistributionRatio(
              agentDashboard.summary.redistributions_away_count,
              agentDashboard.summary.redistribution_basis_count
            )
          "
          icon="i-lucide-route"
          tone="danger"
        />
        <MetricCard
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.CARDS.RESOLVED')"
          :value="formatNumber(agentDashboard.summary.resolved_count)"
          icon="i-lucide-check-circle-2"
          tone="success"
        />
      </section>

      <section class="mt-5 grid min-h-0 gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.BY_TEAM') }}
          </h2>
          <BarList
            :items="agentTeamBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.AGENT.RESPONSE_TREND') }}
          </h2>
          <TrendBars
            :items="agentDailyBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
      </section>

      <SuggestionList
        class="mt-5"
        :title="t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUGGESTIONS.TITLE')"
        :items="localizedSuggestions"
      />
    </template>

    <template v-else-if="activeTab === 'supervisor' && supervisorDashboard">
      <section class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          :label="t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.CARDS.OPEN')"
          :value="formatNumber(supervisorDashboard.summary.open_conversations)"
          icon="i-lucide-inbox"
        />
        <MetricCard
          :label="
            t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.CARDS.UNASSIGNED')
          "
          :value="
            formatNumber(supervisorDashboard.summary.unassigned_conversations)
          "
          icon="i-lucide-user-x"
          tone="warning"
        />
        <MetricCard
          :label="
            t(
              'IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.CARDS.AVG_FIRST_RESPONSE'
            )
          "
          :value="
            formatDuration(
              supervisorDashboard.summary.average_first_response_seconds
            )
          "
          icon="i-lucide-timer"
        />
        <MetricCard
          :label="
            t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.CARDS.REDISTRIBUTIONS')
          "
          :value="
            formatNumber(supervisorDashboard.summary.redistributions_count)
          "
          :hint="
            formatRedistributionRatio(
              supervisorDashboard.summary.redistributions_count,
              supervisorDashboard.summary.redistribution_basis_count
            )
          "
          icon="i-lucide-route"
          tone="danger"
        />
      </section>

      <section class="mt-5 grid gap-5 xl:grid-cols-2">
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.TOP_AGENTS') }}
          </h2>
          <BarList
            :items="topAgentBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{
              t(
                'IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.REDISTRIBUTION_RANKING'
              )
            }}
          </h2>
          <BarList
            :items="redistributionBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.SLOW_RESPONSE') }}
          </h2>
          <BarList
            :items="slowResponseBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.TEAM_HEALTH') }}
          </h2>
          <BarList
            :items="teamHealthBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
          />
        </div>
      </section>

      <section class="mt-5 grid gap-5 xl:grid-cols-[1.1fr_0.9fr]">
        <div
          class="flex min-h-80 flex-col rounded-lg border border-n-weak bg-n-alpha-1 p-4"
        >
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.DAILY_VOLUME') }}
          </h2>
          <TrendBars
            class="min-h-0 flex-1"
            :items="dailyVolumeBars"
            :empty-text="t('IBSOFT_THEME.CHATHUB_ANALYTICS.EMPTY')"
            fill-height
          />
        </div>
        <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
          <h2 class="mb-3 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUPERVISOR.HOURLY_HEATMAP') }}
          </h2>
          <div class="grid grid-cols-6 gap-2">
            <div
              v-for="item in heatmapItems"
              :key="item.hour"
              class="rounded-lg bg-n-alpha-1 p-2 text-center"
            >
              <div
                class="mx-auto mb-1 size-8 rounded-lg bg-n-brand"
                :style="{ opacity: Math.max(item.percent / 100, 0.12) }"
              />
              <span class="block text-label-small text-n-slate-11">
                {{ formatHourLabel(item.hour) }}
              </span>
            </div>
          </div>
        </div>
      </section>

      <SuggestionList
        class="mt-5"
        :title="t('IBSOFT_THEME.CHATHUB_ANALYTICS.SUGGESTIONS.TITLE')"
        :items="localizedSuggestions"
      />
    </template>
  </main>
</template>
