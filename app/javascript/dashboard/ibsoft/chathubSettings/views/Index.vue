<script setup>
import { computed, defineAsyncComponent, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import chathubSettingsAPI from '../api';
import { normalizeChathubSettingsConfig } from '../defaults';
import DistributionPolicyCatalog from '../components/DistributionPolicyCatalog.vue';
import AccessControlPanel from 'dashboard/ibsoft/accessControl/components/AccessControlPanel.vue';
import AgentProvisioningPanel from 'dashboard/ibsoft/agentProvisioning/components/AgentProvisioningPanel.vue';
import { settingsSections } from '../settingsSections';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const store = useStore();

const DEFAULT_SECTION = 'attendance';
const BASE_SECTION_IDS = Object.freeze(['attendance', 'policies']);
const ADMIN_SECTION_IDS = Object.freeze([
  ...settingsSections.map(section => section.id),
  'agent_provisioning',
  'access_control',
]);

const isFetching = ref(false);
const isSaving = ref(false);
const config = ref(normalizeChathubSettingsConfig());
const activeSection = ref(DEFAULT_SECTION);

const currentAccount = computed(() => {
  const accountId = Number(store.getters.getCurrentAccountId);
  return store.getters.getCurrentUser?.accounts?.find(
    account => account.id === accountId
  );
});

const isAdmin = computed(() => currentAccount.value?.role === 'administrator');

const integratedSections = settingsSections.map(section => ({
  ...section,
  component: defineAsyncComponent(section.loader),
}));

const activeIntegratedSection = computed(() =>
  integratedSections.find(section => section.id === activeSection.value)
);

const knownSectionIds = computed(() => [
  ...BASE_SECTION_IDS,
  ...(isAdmin.value ? ADMIN_SECTION_IDS : []),
]);

const resolveSection = sectionId => {
  if (knownSectionIds.value.includes(sectionId)) return sectionId;
  return DEFAULT_SECTION;
};

const selectSection = sectionId => {
  const nextSection = resolveSection(sectionId);
  activeSection.value = nextSection;

  const query = { ...route.query };
  if (nextSection === DEFAULT_SECTION) {
    delete query.section;
  } else {
    query.section = nextSection;
  }

  router.replace({ query });
};

const integratedSectionLabel = sectionId => {
  if (sectionId === 'channels') {
    return t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.CHANNELS');
  }

  if (sectionId === 'teams') {
    return t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.TEAMS');
  }

  return t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCOUNT');
};

const menuItems = computed(() => {
  const items = [
    {
      id: 'attendance',
      icon: 'i-lucide-headset',
      label: t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ATTENDANCE'),
    },
    {
      id: 'policies',
      icon: 'i-lucide-workflow',
      label: t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.POLICIES'),
    },
  ];

  if (isAdmin.value) {
    items.unshift(
      ...integratedSections.map(section => ({
        id: section.id,
        icon: section.icon,
        label: integratedSectionLabel(section.id),
      }))
    );

    items.push({
      id: 'agent_provisioning',
      icon: 'i-lucide-user-plus',
      label: t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.AGENTS'),
    });

    items.push({
      id: 'access_control',
      icon: 'i-lucide-shield-check',
      label: t('IBSOFT_THEME.CHATHUB_SETTINGS.MENU.ACCESS_CONTROL'),
    });
  }

  return items;
});

const numberValue = (section, key, event) => {
  const value = Number(event.target.value);
  config.value[section][key] = Number.isFinite(value) && value >= 0 ? value : 0;
};

const positiveNumberValue = (section, key, event) => {
  const value = Number(event.target.value);
  config.value[section][key] = Number.isFinite(value) && value > 0 ? value : 1;
};

const fetchSettings = async () => {
  isFetching.value = true;
  try {
    const { data } = await chathubSettingsAPI.getSettings();
    config.value = normalizeChathubSettingsConfig(data.config);
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const saveSettings = async () => {
  isSaving.value = true;
  try {
    const { data } = await chathubSettingsAPI.updateSettings({
      config: config.value,
    });
    config.value = normalizeChathubSettingsConfig(data.config);
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.SAVED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  await fetchSettings();
});

watch(
  [() => route.query.section, knownSectionIds],
  ([section]) => {
    activeSection.value = resolveSection(section);
  },
  { immediate: true }
);
</script>

<template>
  <section class="flex h-full min-w-0 flex-1 overflow-hidden bg-n-background">
    <aside
      class="hidden w-72 shrink-0 border-r border-n-weak p-4 md:block xl:w-80"
    >
      <h1 class="mb-1 text-heading-1 text-n-slate-12">
        {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.TITLE') }}
      </h1>
      <p class="mb-5 text-body-small text-n-slate-11">
        {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.DESCRIPTION') }}
      </p>
      <nav class="space-y-1">
        <button
          v-for="item in menuItems"
          :key="item.id"
          type="button"
          class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-left text-sm font-medium text-n-slate-12"
          :class="
            activeSection === item.id ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'
          "
          @click="selectSection(item.id)"
        >
          <i class="size-4" :class="[item.icon]" />
          {{ item.label }}
        </button>
      </nav>
    </aside>

    <main class="min-w-0 flex-1 overflow-y-auto p-4 md:p-6">
      <div
        class="mx-auto grid w-full gap-5"
        :class="activeIntegratedSection ? 'max-w-7xl' : 'max-w-5xl'"
      >
        <header class="md:hidden">
          <h1 class="mb-1 text-heading-1 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.TITLE') }}
          </h1>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.DESCRIPTION') }}
          </p>
        </header>

        <div v-if="isFetching" class="grid min-h-80 place-content-center">
          <Spinner />
        </div>

        <template v-else>
          <template v-if="activeSection === 'attendance'">
            <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
              <div class="mb-4 flex items-start justify-between gap-4">
                <div>
                  <h2 class="mb-1 text-heading-2 text-n-slate-12">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.AGENT_ENTRY.TITLE'
                      )
                    }}
                  </h2>
                  <p class="mb-0 text-body-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.AGENT_ENTRY.DESCRIPTION'
                      )
                    }}
                  </p>
                </div>
                <ToggleSwitch
                  v-model="config.agent_entry_assignment.enabled"
                  class="shrink-0"
                />
              </div>

              <div class="grid gap-4 md:grid-cols-2">
                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.AGENT_ENTRY.PERCENTAGE'
                      )
                    }}
                  </span>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                    :value="config.agent_entry_assignment.required_percentage"
                    @input="
                      numberValue(
                        'agent_entry_assignment',
                        'required_percentage',
                        $event
                      )
                    "
                  />
                </label>

                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.AGENT_ENTRY.MINIMUM'
                      )
                    }}
                  </span>
                  <input
                    type="number"
                    min="1"
                    class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                    :value="config.agent_entry_assignment.minimum_required"
                    @input="
                      positiveNumberValue(
                        'agent_entry_assignment',
                        'minimum_required',
                        $event
                      )
                    "
                  />
                </label>

                <label
                  class="flex items-center justify-between gap-3 rounded-lg border border-n-weak px-3 py-2"
                >
                  <span class="text-sm text-n-slate-12">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.AGENT_ENTRY.BLOCK_CLOSE'
                      )
                    }}
                  </span>
                  <ToggleSwitch
                    v-model="
                      config.agent_entry_assignment.block_close_when_required
                    "
                  />
                </label>
              </div>
            </section>

            <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
              <div class="mb-4 flex items-start justify-between gap-4">
                <div>
                  <h2 class="mb-1 text-heading-2 text-n-slate-12">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.TITLE'
                      )
                    }}
                  </h2>
                  <p class="mb-0 text-body-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.DESCRIPTION'
                      )
                    }}
                  </p>
                </div>
                <ToggleSwitch
                  v-model="config.login_stabilization.enabled"
                  class="shrink-0"
                />
              </div>

              <div class="grid gap-4 md:grid-cols-2">
                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.OFFLINE_THRESHOLD'
                      )
                    }}
                  </span>
                  <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
                    <input
                      type="number"
                      min="1"
                      class="!h-12 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 !py-0 text-sm text-n-slate-12"
                      :value="
                        config.login_stabilization.offline_threshold_minutes
                      "
                      @input="
                        positiveNumberValue(
                          'login_stabilization',
                          'offline_threshold_minutes',
                          $event
                        )
                      "
                    />
                    <span
                      class="flex h-12 min-w-28 items-center justify-center rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11"
                    >
                      {{
                        t(
                          'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.UNITS.MINUTES'
                        )
                      }}
                    </span>
                  </div>
                </label>

                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.WINDOW'
                      )
                    }}
                  </span>
                  <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
                    <input
                      type="number"
                      min="1"
                      class="!h-12 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 !py-0 text-sm text-n-slate-12"
                      :value="config.login_stabilization.window_minutes"
                      @input="
                        positiveNumberValue(
                          'login_stabilization',
                          'window_minutes',
                          $event
                        )
                      "
                    />
                    <span
                      class="flex h-12 min-w-28 items-center justify-center rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11"
                    >
                      {{
                        t(
                          'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.UNITS.MINUTES'
                        )
                      }}
                    </span>
                  </div>
                </label>

                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.MAX_DURING_WINDOW'
                      )
                    }}
                  </span>
                  <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
                    <input
                      type="number"
                      min="1"
                      class="!h-12 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 !py-0 text-sm text-n-slate-12"
                      :value="
                        config.login_stabilization.max_assignments_during_window
                      "
                      @input="
                        positiveNumberValue(
                          'login_stabilization',
                          'max_assignments_during_window',
                          $event
                        )
                      "
                    />
                    <span
                      class="flex h-12 min-w-32 items-center justify-center rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11"
                    >
                      {{
                        t(
                          'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.UNITS.CONVERSATIONS'
                        )
                      }}
                    </span>
                  </div>
                </label>

                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.MIN_ONLINE'
                      )
                    }}
                  </span>
                  <div class="grid grid-cols-[minmax(0,1fr)_auto] gap-2">
                    <input
                      type="number"
                      min="1"
                      class="!h-12 w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 !py-0 text-sm text-n-slate-12"
                      :value="
                        config.login_stabilization
                          .minimum_online_agents_to_disable
                      "
                      @input="
                        positiveNumberValue(
                          'login_stabilization',
                          'minimum_online_agents_to_disable',
                          $event
                        )
                      "
                    />
                    <span
                      class="flex h-12 min-w-36 items-center justify-center rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-11"
                    >
                      {{
                        t(
                          'IBSOFT_THEME.CHATHUB_SETTINGS.ATTENDANCE.STABILIZATION.UNITS.ONLINE_AGENTS'
                        )
                      }}
                    </span>
                  </div>
                </label>
              </div>
            </section>

            <footer class="flex justify-end">
              <Button
                :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.SAVE')"
                icon="i-lucide-save"
                :is-loading="isSaving"
                @click="saveSettings"
              />
            </footer>
          </template>

          <DistributionPolicyCatalog v-else-if="activeSection === 'policies'" />
          <component
            :is="activeIntegratedSection?.component"
            v-else-if="activeIntegratedSection && isAdmin"
          />
          <AgentProvisioningPanel
            v-else-if="activeSection === 'agent_provisioning' && isAdmin"
          />
          <AccessControlPanel
            v-else-if="activeSection === 'access_control' && isAdmin"
          />
        </template>
      </div>
    </main>
  </section>
</template>
