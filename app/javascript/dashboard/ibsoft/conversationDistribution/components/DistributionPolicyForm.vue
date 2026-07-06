<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Banner from 'dashboard/components-next/banner/Banner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import DurationInput from 'dashboard/components-next/input/DurationInput.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';
import RadioCard from 'dashboard/components-next/radioCard/RadioCard.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import {
  defaultTimeSlot,
  timeSlotParse,
  timeSlotTransform,
  timeZoneOptions,
} from 'dashboard/routes/dashboard/settings/inbox/helpers/businessHour';
import {
  ibsoftBusinessHoursTimezoneOption,
  ibsoftDefaultBusinessHoursTimezone,
} from 'dashboard/ibsoft/localization/businessHoursDefaults';
import {
  parseWorkingHourBreaks,
  transformWorkingHourBreaks,
} from 'dashboard/ibsoft/localization/workingHourBreaks';
import { normalizePolicyConfig } from '../policyDefaults';
import PolicyBusinessHourDay from './PolicyBusinessHourDay.vue';

const props = defineProps({
  enabled: {
    type: Boolean,
    default: false,
  },
  modelValue: {
    type: Object,
    default: () => ({}),
  },
  overrideChannelPolicy: {
    type: Boolean,
    default: false,
  },
  teams: {
    type: Array,
    default: () => [],
  },
  isTeamPolicy: {
    type: Boolean,
    default: false,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  showActions: {
    type: Boolean,
    default: true,
  },
  activationWarnings: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits([
  'update:enabled',
  'update:modelValue',
  'update:overrideChannelPolicy',
  'save',
]);

const { t } = useI18n();
const store = useStore();
const defaultBusinessHourSlots = () =>
  defaultTimeSlot.map(slot => {
    const isWeekday = slot.day >= 1 && slot.day <= 5;

    return {
      ...slot,
      from: isWeekday ? '09:00 AM' : '',
      to: isWeekday ? '05:00 PM' : '',
      valid: isWeekday,
      openAllDay: false,
    };
  });

const normalizeBusinessHourSlots = schedule => {
  const parsedSlots = timeSlotParse(schedule || []);
  const slots = parsedSlots.length ? parsedSlots : defaultBusinessHourSlots();

  return defaultTimeSlot.map(defaultSlot => {
    const slot = slots.find(item => item.day === defaultSlot.day);
    return slot || defaultBusinessHourSlots()[defaultSlot.day];
  });
};

const config = ref(normalizePolicyConfig(props.modelValue));
const businessHourSlots = ref(
  normalizeBusinessHourSlots(config.value.business_hours.schedule)
);
const businessHourBreaks = ref(
  parseWorkingHourBreaks(config.value.business_hours.breaks)
);

const secondsToMinutes = value => Math.floor((Number(value) || 0) / 60);

const detectDurationUnit = minutes => {
  const value = Number(minutes) || 0;

  if (value === 0) return DURATION_UNITS.MINUTES;
  if (value % (24 * 60) === 0) return DURATION_UNITS.DAYS;
  if (value % 60 === 0) return DURATION_UNITS.HOURS;

  return DURATION_UNITS.MINUTES;
};

const fairDistributionWindowUnit = ref(
  detectDurationUnit(
    secondsToMinutes(config.value.distribution.fair_distribution_window)
  )
);
const customerWaitingWindowUnit = ref(
  detectDurationUnit(
    config.value.distribution.capacity_ignore_customer_waiting_minutes
  )
);

watch(
  () => props.modelValue,
  value => {
    config.value = normalizePolicyConfig(value);
    businessHourSlots.value = normalizeBusinessHourSlots(
      config.value.business_hours.schedule
    );
    businessHourBreaks.value = parseWorkingHourBreaks(
      config.value.business_hours.breaks
    );
    fairDistributionWindowUnit.value = detectDurationUnit(
      secondsToMinutes(config.value.distribution.fair_distribution_window)
    );
    customerWaitingWindowUnit.value = detectDurationUnit(
      config.value.distribution.capacity_ignore_customer_waiting_minutes
    );
  },
  { deep: true }
);

const enabledModel = computed({
  get: () => props.enabled,
  set: value => emit('update:enabled', value),
});

const overrideModel = computed({
  get: () => props.overrideChannelPolicy,
  set: value => emit('update:overrideChannelPolicy', value),
});

const fallbackTeams = computed(() =>
  props.teams.map(team => ({ id: team.id, name: team.name }))
);

const timeZones = computed(() => [...timeZoneOptions()]);
const labelOptions = computed(() =>
  (store.getters['labels/getLabels'] || [])
    .map(label => ({
      value: label.title,
      label: label.title,
    }))
    .sort((first, second) => first.label.localeCompare(second.label))
);

const emitConfig = () => {
  emit('update:modelValue', normalizePolicyConfig(config.value));
};

const timeZoneValue = computed({
  get() {
    return ibsoftBusinessHoursTimezoneOption(
      config.value.business_hours.timezone,
      timeZones.value
    ).value;
  },
  set(value) {
    config.value.business_hours.timezone = value;
    emitConfig();
  },
});

const fairDistributionLimit = computed({
  get: () => config.value.distribution.fair_distribution_limit,
  set(value) {
    config.value.distribution.fair_distribution_limit = value;
    emitConfig();
  },
});

const fairDistributionWindow = computed({
  get: () => config.value.distribution.fair_distribution_window,
  set(value) {
    config.value.distribution.fair_distribution_window = value;
    emitConfig();
  },
});

const fairDistributionWindowInMinutes = computed({
  get: () => secondsToMinutes(fairDistributionWindow.value),
  set(value) {
    fairDistributionWindow.value = (Number(value) || 0) * 60;
  },
});

const openConversationLimit = computed({
  get: () => config.value.distribution.open_conversation_limit,
  set(value) {
    config.value.distribution.open_conversation_limit = value;
    emitConfig();
  },
});

const capacityExcludedLabels = computed({
  get: () => config.value.distribution.capacity_excluded_labels || [],
  set(value) {
    config.value.distribution.capacity_excluded_labels = value || [];
    emitConfig();
  },
});

const capacityIgnoreCustomerWaitingEnabled = computed({
  get: () => config.value.distribution.capacity_ignore_customer_waiting_enabled,
  set(value) {
    config.value.distribution.capacity_ignore_customer_waiting_enabled = value;
    emitConfig();
  },
});

const capacityIgnoreCustomerWaitingMinutes = computed({
  get: () => config.value.distribution.capacity_ignore_customer_waiting_minutes,
  set(value) {
    config.value.distribution.capacity_ignore_customer_waiting_minutes = value;
    emitConfig();
  },
});

const maxRoundLimitEnabled = computed({
  get: () => config.value.distribution.max_assignments_per_round_enabled,
  set(value) {
    config.value.distribution.max_assignments_per_round_enabled = value;
    emitConfig();
  },
});

const redistributionEnabled = computed({
  get: () => config.value.redistribution.enabled,
  set(value) {
    config.value.redistribution.enabled = value;
    emitConfig();
  },
});

const assignmentConfirmationEnabled = computed({
  get: () => config.value.assignment_confirmation.enabled,
  set(value) {
    config.value.assignment_confirmation.enabled = value;
    if (value && !config.value.assignment_confirmation.message) {
      config.value.assignment_confirmation.message = t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.DEFAULT_MESSAGE'
      );
    }
    emitConfig();
  },
});

const assignmentConfirmationOnlyBeforeFirstReply = computed({
  get: () => config.value.assignment_confirmation.only_before_first_reply,
  set(value) {
    config.value.assignment_confirmation.only_before_first_reply = value;
    emitConfig();
  },
});

const supervisorAlertEnabled = computed({
  get: () => config.value.supervisor_alert.enabled,
  set(value) {
    config.value.supervisor_alert.enabled = value;
    emitConfig();
  },
});

const hasActivationWarnings = computed(
  () => props.activationWarnings.length > 0
);

const assignmentOrderOptions = computed(() => [
  {
    key: 'round_robin',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.ROUND_ROBIN.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.ROUND_ROBIN.DESCRIPTION'
    ),
  },
  {
    key: 'balanced',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.BALANCED.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.BALANCED.DESCRIPTION'
    ),
  },
]);

const assignmentPriorityOptions = computed(() => [
  {
    key: 'longest_waiting',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.LONGEST_WAITING.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.LONGEST_WAITING.DESCRIPTION'
    ),
  },
  {
    key: 'earliest_created',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.EARLIEST_CREATED.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.EARLIEST_CREATED.DESCRIPTION'
    ),
  },
]);

const assignmentLimitModeOptions = computed(() => [
  {
    key: 'open_conversations',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.ASSIGNMENT_LIMIT_MODE.OPEN_CONVERSATIONS.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.ASSIGNMENT_LIMIT_MODE.OPEN_CONVERSATIONS.DESCRIPTION'
    ),
  },
  {
    key: 'assignment_window',
    label: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.ASSIGNMENT_LIMIT_MODE.ASSIGNMENT_WINDOW.LABEL'
    ),
    description: t(
      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.ASSIGNMENT_LIMIT_MODE.ASSIGNMENT_WINDOW.DESCRIPTION'
    ),
  },
]);

const businessHourDayNames = computed(() => ({
  0: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.0'),
  1: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.1'),
  2: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.2'),
  3: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.3'),
  4: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.4'),
  5: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.5'),
  6: t('INBOX_MGMT.BUSINESS_HOURS.DAY_NAMES.6'),
}));

const activationWarningLabels = computed(() => ({
  CHANNEL_AUTO_ASSIGNMENT: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.CHANNEL_AUTO_ASSIGNMENT'
  ),
  TEAM_AUTO_ASSIGNMENT: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.TEAM_AUTO_ASSIGNMENT'
  ),
  ASSIGNMENT_POLICY: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.ASSIGNMENT_POLICY'
  ),
}));

const onNumberInput = (section, key, event) => {
  const value = Number(event.target.value);
  config.value[section][key] = Number.isFinite(value) && value > 0 ? value : 1;
  emitConfig();
};

const selectDistributionOption = (key, value) => {
  config.value.distribution[key] = value;
  emitConfig();
};

const persistBusinessHourSlots = () => {
  config.value.business_hours.schedule = timeSlotTransform(
    businessHourSlots.value
  );
};

const persistBusinessHourBreaks = () => {
  config.value.business_hours.breaks = transformWorkingHourBreaks(
    businessHourBreaks.value
  );
};

const ensureCustomBusinessHours = () => {
  if (!config.value.business_hours.timezone) {
    config.value.business_hours.timezone = ibsoftDefaultBusinessHoursTimezone(
      timeZones.value
    ).value;
  }

  if (!config.value.business_hours.schedule?.length) {
    businessHourSlots.value = defaultBusinessHourSlots();
    persistBusinessHourSlots();
  }

  persistBusinessHourBreaks();
};

const onBusinessHoursModeChange = () => {
  if (config.value.business_hours.mode === 'custom') {
    ensureCustomBusinessHours();
  }

  emitConfig();
};

const onBusinessHourSlotUpdate = (day, slotData) => {
  businessHourSlots.value = businessHourSlots.value.map(slot =>
    slot.day === day ? slotData : slot
  );
  persistBusinessHourSlots();
  emitConfig();
};

const onBusinessHourBreaksUpdate = (day, breaks) => {
  businessHourBreaks.value = {
    ...businessHourBreaks.value,
    [day]: breaks,
  };
  persistBusinessHourBreaks();
  emitConfig();
};

const businessHourDayName = day => businessHourDayNames.value[day];

onMounted(() => {
  store.dispatch('labels/get');
});
</script>

<template>
  <div class="space-y-5">
    <slot name="before" />

    <div
      class="flex items-center justify-between gap-4 rounded-xl border border-n-weak px-4 py-3"
    >
      <div class="min-w-0">
        <h4 class="text-heading-3 text-n-slate-12 mb-0.5">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ENABLED.TITLE') }}
        </h4>
        <p class="text-body-main text-n-slate-11 mb-0">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ENABLED.DESCRIPTION') }}
        </p>
      </div>
      <ToggleSwitch v-model="enabledModel" />
    </div>

    <Banner v-if="hasActivationWarnings" color="amber">
      <div class="space-y-1">
        <p class="mb-0 font-medium">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.TITLE')
          }}
        </p>
        <p class="mb-0">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.DESCRIPTION'
            )
          }}
        </p>
        <ul class="mb-0 list-disc ps-4">
          <li v-for="warning in activationWarnings" :key="warning">
            {{ activationWarningLabels[warning] || warning }}
          </li>
        </ul>
      </div>
    </Banner>

    <div
      v-if="isTeamPolicy"
      class="flex items-center justify-between gap-4 rounded-xl border border-n-weak px-4 py-3"
    >
      <div class="min-w-0">
        <h4 class="mb-0.5 text-heading-3 text-n-slate-12">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.TITLE') }}
        </h4>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.DESCRIPTION') }}
        </p>
      </div>
      <ToggleSwitch v-model="overrideModel" />
    </div>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.DESCRIPTION')
      "
    >
      <div class="grid grid-cols-1 gap-5">
        <div class="grid gap-3">
          <h5 class="mb-0 text-heading-3 text-n-slate-12">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ASSIGNMENT_ORDER.TITLE'
              )
            }}
          </h5>
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <RadioCard
              v-for="option in assignmentOrderOptions"
              :id="option.key"
              :key="option.key"
              :label="option.label"
              :description="option.description"
              :is-active="config.distribution.assignment_order === option.key"
              @select="
                value => selectDistributionOption('assignment_order', value)
              "
            />
          </div>
        </div>

        <div class="grid gap-3">
          <h5 class="mb-0 text-heading-3 text-n-slate-12">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CONVERSATION_PRIORITY.TITLE'
              )
            }}
          </h5>
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <RadioCard
              v-for="option in assignmentPriorityOptions"
              :id="option.key"
              :key="option.key"
              :label="option.label"
              :description="option.description"
              :is-active="
                config.distribution.conversation_priority === option.key
              "
              @select="
                value =>
                  selectDistributionOption('conversation_priority', value)
              "
            />
          </div>
        </div>

        <div class="grid gap-2">
          <div>
            <h5 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.TITLE'
                )
              }}
            </h5>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <div
            class="grid gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          >
            <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
              <RadioCard
                v-for="option in assignmentLimitModeOptions"
                :id="option.key"
                :key="option.key"
                :label="option.label"
                :description="option.description"
                :is-active="
                  config.distribution.assignment_limit_mode === option.key
                "
                @select="
                  value =>
                    selectDistributionOption('assignment_limit_mode', value)
                "
              />
            </div>

            <template
              v-if="
                config.distribution.assignment_limit_mode ===
                'open_conversations'
              "
            >
              <Input
                v-model="openConversationLimit"
                type="number"
                min="1"
                max="100000"
                :label="
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.OPEN_LIMIT_LABEL'
                  )
                "
                class="max-w-md"
              />

              <div class="grid gap-4 rounded-xl bg-n-alpha-1 p-4">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <h6 class="mb-1 text-heading-3 text-n-slate-12">
                      {{
                        t(
                          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.TITLE'
                        )
                      }}
                    </h6>
                    <p class="mb-0 text-body-main text-n-slate-11">
                      {{
                        t(
                          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.DESCRIPTION'
                        )
                      }}
                    </p>
                  </div>
                </div>

                <label class="grid gap-1">
                  <span class="text-label-small text-n-slate-11">
                    {{
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.LABELS'
                      )
                    }}
                  </span>
                  <TagMultiSelectComboBox
                    v-model="capacityExcludedLabels"
                    :options="labelOptions"
                    :placeholder="
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.LABELS_PLACEHOLDER'
                      )
                    "
                    :search-placeholder="
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.LABELS_SEARCH'
                      )
                    "
                    :empty-state="
                      t(
                        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.LABELS_EMPTY'
                      )
                    "
                  />
                </label>

                <div class="grid gap-3">
                  <div class="flex items-start justify-between gap-4">
                    <div>
                      <h6 class="mb-1 text-heading-3 text-n-slate-12">
                        {{
                          t(
                            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.WAITING_CUSTOMER_TITLE'
                          )
                        }}
                      </h6>
                      <p class="mb-0 text-body-main text-n-slate-11">
                        {{
                          t(
                            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.WAITING_CUSTOMER_DESCRIPTION'
                          )
                        }}
                      </p>
                    </div>
                    <ToggleSwitch
                      v-model="capacityIgnoreCustomerWaitingEnabled"
                      class="shrink-0"
                    />
                  </div>

                  <label
                    v-if="capacityIgnoreCustomerWaitingEnabled"
                    class="grid max-w-md gap-1"
                  >
                    <span class="text-label-small text-n-slate-11">
                      {{
                        t(
                          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.CAPACITY.EXCLUSIONS.WAITING_CUSTOMER_LIMIT'
                        )
                      }}
                    </span>
                    <div
                      class="flex items-center gap-2 [&>select]:!mb-0 [&>select]:!bg-n-alpha-2 [&>select]:!outline-none [&>select]:hover:brightness-110"
                    >
                      <DurationInput
                        v-model:model-value="
                          capacityIgnoreCustomerWaitingMinutes
                        "
                        v-model:unit="customerWaitingWindowUnit"
                        :min="1"
                        :max="1438560"
                      />
                    </div>
                  </label>
                </div>
              </div>
            </template>

            <div v-else class="grid grid-cols-1 gap-4 md:grid-cols-2">
              <Input
                v-model="fairDistributionLimit"
                type="number"
                min="1"
                max="100000"
                :label="
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.FAIR_DISTRIBUTION.LIMIT_LABEL'
                  )
                "
                class="w-full"
              />

              <label class="grid gap-1">
                <span class="text-heading-3 text-n-slate-12">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.FAIR_DISTRIBUTION.WINDOW_LABEL'
                    )
                  }}
                </span>
                <div
                  class="flex items-center gap-2 [&>select]:!mb-0 [&>select]:!bg-n-alpha-2 [&>select]:!outline-none [&>select]:hover:brightness-110"
                >
                  <DurationInput
                    v-model:model-value="fairDistributionWindowInMinutes"
                    v-model:unit="fairDistributionWindowUnit"
                    :min="10"
                    :max="1438560"
                  />
                </div>
              </label>
            </div>
          </div>
        </div>
      </div>

      <div class="grid gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h5 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ROUND_LIMIT.TITLE'
                )
              }}
            </h5>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.ROUND_LIMIT.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <ToggleSwitch v-model="maxRoundLimitEnabled" />
        </div>

        <label v-if="maxRoundLimitEnabled" class="flex max-w-md flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.MAX_PER_ROUND'
              )
            }}
          </span>
          <input
            :value="config.distribution.max_assignments_per_round"
            type="number"
            min="1"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
            @input="
              onNumberInput('distribution', 'max_assignments_per_round', $event)
            "
          />
        </label>
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.DESCRIPTION')
      "
    >
      <div class="flex items-center justify-between gap-4">
        <p class="mb-0 text-body-main text-n-slate-12">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.ENABLE_TIMEOUT'
            )
          }}
        </p>
        <ToggleSwitch v-model="redistributionEnabled" />
      </div>
      <label v-if="redistributionEnabled" class="mt-3 flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.TIMEOUT')
          }}
        </span>
        <input
          :value="config.redistribution.first_response_timeout_minutes"
          type="number"
          min="1"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          @input="
            onNumberInput(
              'redistribution',
              'first_response_timeout_minutes',
              $event
            )
          "
        />
      </label>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="
        t(
          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.TITLE'
        )
      "
      :help-text="
        t(
          'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.DESCRIPTION'
        )
      "
    >
      <div class="grid gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4">
        <div class="flex items-start justify-between gap-4">
          <div>
            <h5 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.ENABLED'
                )
              }}
            </h5>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.ENABLED_DESCRIPTION'
                )
              }}
            </p>
          </div>
          <ToggleSwitch v-model="assignmentConfirmationEnabled" />
        </div>

        <template v-if="assignmentConfirmationEnabled">
          <label class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.MESSAGE'
                )
              }}
            </span>
            <textarea
              v-model="config.assignment_confirmation.message"
              rows="3"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
              @input="emitConfig"
            />
          </label>

          <div class="flex items-start justify-between gap-4">
            <div>
              <h6 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.ONLY_BEFORE_FIRST_REPLY'
                  )
                }}
              </h6>
              <p class="mb-0 text-body-main text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ASSIGNMENT_CONFIRMATION.ONLY_BEFORE_FIRST_REPLY_DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <ToggleSwitch
              v-model="assignmentConfirmationOnlyBeforeFirstReply"
            />
          </div>
        </template>
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.DESCRIPTION')
      "
    >
      <div class="grid grid-cols-1 gap-4">
        <div
          class="grid gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div>
            <h5 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.NO_AVAILABLE_AGENT.TITLE'
                )
              }}
            </h5>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.NO_AVAILABLE_AGENT.DESCRIPTION'
                )
              }}
            </p>
          </div>

          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span class="text-label-small text-n-slate-11">
                {{
                  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.ACTION')
                }}
              </span>
              <IbsoftSelect
                v-model="config.unavailability.no_available_agent.action"
                @change="emitConfig"
              >
                <option value="wait">
                  {{
                    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.WAIT')
                  }}
                </option>
                <option value="notify_customer">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.NOTIFY_CUSTOMER'
                    )
                  }}
                </option>
                <option value="fallback_team">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.FALLBACK_TEAM'
                    )
                  }}
                </option>
              </IbsoftSelect>
            </label>

            <label
              v-if="
                config.unavailability.no_available_agent.action ===
                'fallback_team'
              "
              class="flex flex-col gap-1"
            >
              <span class="text-label-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.FALLBACK_TEAM_LABEL'
                  )
                }}
              </span>
              <IbsoftSelect
                v-model="
                  config.unavailability.no_available_agent.fallback_team_id
                "
                @change="emitConfig"
              >
                <option :value="null">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.SELECT_TEAM'
                    )
                  }}
                </option>
                <option
                  v-for="team in fallbackTeams"
                  :key="team.id"
                  :value="team.id"
                >
                  {{ team.name }}
                </option>
              </IbsoftSelect>
            </label>
          </div>

          <label
            v-if="
              config.unavailability.no_available_agent.action ===
              'notify_customer'
            "
            class="flex flex-col gap-1"
          >
            <span class="text-label-small text-n-slate-11">
              {{
                t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.MESSAGE')
              }}
            </span>
            <textarea
              v-model="config.unavailability.no_available_agent.message"
              rows="3"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
              @input="emitConfig"
            />
          </label>
        </div>

        <div
          class="grid gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <div>
            <h5 class="mb-1 text-heading-3 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.OUTSIDE_BUSINESS_HOURS.TITLE'
                )
              }}
            </h5>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.OUTSIDE_BUSINESS_HOURS.DESCRIPTION'
                )
              }}
            </p>
          </div>

          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span class="text-label-small text-n-slate-11">
                {{
                  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.ACTION')
                }}
              </span>
              <IbsoftSelect
                v-model="config.unavailability.outside_business_hours.action"
                @change="emitConfig"
              >
                <option value="wait">
                  {{
                    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.WAIT')
                  }}
                </option>
                <option value="notify_customer">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.NOTIFY_CUSTOMER'
                    )
                  }}
                </option>
                <option value="fallback_team">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.FALLBACK_TEAM'
                    )
                  }}
                </option>
              </IbsoftSelect>
            </label>

            <label
              v-if="
                config.unavailability.outside_business_hours.action ===
                'fallback_team'
              "
              class="flex flex-col gap-1"
            >
              <span class="text-label-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.FALLBACK_TEAM_LABEL'
                  )
                }}
              </span>
              <IbsoftSelect
                v-model="
                  config.unavailability.outside_business_hours.fallback_team_id
                "
                @change="emitConfig"
              >
                <option :value="null">
                  {{
                    t(
                      'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.SELECT_TEAM'
                    )
                  }}
                </option>
                <option
                  v-for="team in fallbackTeams"
                  :key="team.id"
                  :value="team.id"
                >
                  {{ team.name }}
                </option>
              </IbsoftSelect>
            </label>
          </div>

          <label
            v-if="
              config.unavailability.outside_business_hours.action ===
              'notify_customer'
            "
            class="flex flex-col gap-1"
          >
            <span class="text-label-small text-n-slate-11">
              {{
                t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.MESSAGE')
              }}
            </span>
            <textarea
              v-model="config.unavailability.outside_business_hours.message"
              rows="3"
              class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
              @input="emitConfig"
            />
          </label>
        </div>
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.DESCRIPTION')
      "
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.MODE')
            }}
          </span>
          <IbsoftSelect
            v-model="config.business_hours.mode"
            @change="onBusinessHoursModeChange"
          >
            <option value="inherit_channel">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.INHERIT_CHANNEL'
                )
              }}
            </option>
            <option value="custom">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.CUSTOM'
                )
              }}
            </option>
            <option value="always_available">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.ALWAYS_AVAILABLE'
                )
              }}
            </option>
          </IbsoftSelect>
        </label>
      </div>

      <template v-if="config.business_hours.mode === 'custom'">
        <label class="mt-4 flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.TIMEZONE_LABEL'
              )
            }}
          </span>
          <ComboBox
            v-model="timeZoneValue"
            :options="timeZones"
            :placeholder="
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.TIMEZONE_PLACEHOLDER'
              )
            "
            class="[&>div>button]:!bg-n-alpha-black2"
          />
        </label>

        <div class="mt-5">
          <div class="mb-3 flex items-center py-1">
            <div class="h-px flex-1 bg-n-weak" />
            <span class="text-body-main px-2 text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.BUSINESS_HOURS.WEEKLY_TITLE'
                )
              }}
            </span>
            <div class="h-px flex-1 bg-n-weak" />
          </div>
          <table
            class="min-w-full table-auto rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <thead>
              <tr class="border-b border-n-weak">
                <th
                  class="py-3 text-start text-heading-3 text-n-slate-12 ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4"
                >
                  {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.DAY') }}
                </th>
                <th
                  class="py-3 text-start text-heading-3 text-n-slate-12 ltr:pr-3 rtl:pl-3"
                >
                  {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.AVAILABILITY') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <PolicyBusinessHourDay
                v-for="timeSlot in businessHourSlots"
                :key="timeSlot.day"
                :day-name="businessHourDayName(timeSlot.day)"
                :time-slot="timeSlot"
                :break-slots="businessHourBreaks[timeSlot.day] || []"
                @update="data => onBusinessHourSlotUpdate(timeSlot.day, data)"
                @update-breaks="
                  data => onBusinessHourBreaksUpdate(timeSlot.day, data)
                "
              />
            </tbody>
          </table>
        </div>
      </template>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.TITLE')
      "
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.DESCRIPTION')
      "
    >
      <div class="flex items-center justify-between gap-4">
        <p class="mb-0 text-body-main text-n-slate-12">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.ENABLED')
          }}
        </p>
        <ToggleSwitch v-model="supervisorAlertEnabled" />
      </div>
      <label v-if="supervisorAlertEnabled" class="mt-3 flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.THRESHOLD'
            )
          }}
        </span>
        <input
          :value="config.supervisor_alert.threshold_minutes"
          type="number"
          min="1"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          @input="
            onNumberInput('supervisor_alert', 'threshold_minutes', $event)
          "
        />
      </label>
    </SettingsFieldSection>

    <div v-if="showActions" class="flex justify-end">
      <NextButton
        :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIONS.SAVE')"
        :is-loading="isLoading"
        @click="$emit('save')"
      />
    </div>
  </div>
</template>
