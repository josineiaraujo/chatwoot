<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import NextButton from 'dashboard/components-next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import { normalizePolicyConfig } from '../policyDefaults';

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
});

const emit = defineEmits([
  'update:enabled',
  'update:modelValue',
  'update:overrideChannelPolicy',
  'save',
]);

const { t } = useI18n();
const config = ref(normalizePolicyConfig(props.modelValue));

watch(
  () => props.modelValue,
  value => {
    config.value = normalizePolicyConfig(value);
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

const emitConfig = () => {
  emit('update:modelValue', normalizePolicyConfig(config.value));
};

const onNumberInput = (section, key, event) => {
  const value = Number(event.target.value);
  config.value[section][key] = Number.isFinite(value) && value > 0 ? value : 1;
  emitConfig();
};
</script>

<template>
  <div class="space-y-5">
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

    <label
      v-if="isTeamPolicy"
      class="flex items-start gap-3 rounded-xl border border-n-weak px-4 py-3"
    >
      <input v-model="overrideModel" type="checkbox" class="mt-1" />
      <span class="min-w-0">
        <span class="block text-heading-3 text-n-slate-12">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.TITLE') }}
        </span>
        <span class="block text-body-main text-n-slate-11">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.DESCRIPTION') }}
        </span>
      </span>
    </label>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.DESCRIPTION')
      "
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.MIN_ON_LOGIN'
              )
            }}
          </span>
          <input
            :value="config.distribution.min_assignments_on_login"
            type="number"
            min="1"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
            @input="
              onNumberInput('distribution', 'min_assignments_on_login', $event)
            "
          />
        </label>

        <label class="flex flex-col gap-1">
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

      <label class="mt-3 flex items-start gap-3">
        <input
          v-model="config.distribution.assign_all_when_single_agent"
          type="checkbox"
          class="mt-1"
          @change="emitConfig"
        />
        <span class="text-body-main text-n-slate-12">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.DISTRIBUTION.SINGLE_AGENT'
            )
          }}
        </span>
      </label>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.DESCRIPTION')
      "
    >
      <label class="flex items-start gap-3">
        <input
          v-model="config.redistribution.enabled"
          type="checkbox"
          class="mt-1"
          @change="emitConfig"
        />
        <span class="text-body-main text-n-slate-12">
          {{
            t(
              'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.REDISTRIBUTION.ENABLE_TIMEOUT'
            )
          }}
        </span>
      </label>
      <label class="mt-3 flex flex-col gap-1">
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
      :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.TITLE')"
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.DESCRIPTION')
      "
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.ACTION') }}
          </span>
          <select
            v-model="config.unavailable.action"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
            @change="emitConfig"
          >
            <option value="wait">
              {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.WAIT') }}
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
          </select>
        </label>

        <label
          v-if="config.unavailable.action === 'fallback_team'"
          class="flex flex-col gap-1"
        >
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.FALLBACK_TEAM_LABEL'
              )
            }}
          </span>
          <select
            v-model.number="config.unavailable.fallback_team_id"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
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
          </select>
        </label>
      </div>

      <label
        v-if="config.unavailable.action === 'notify_customer'"
        class="mt-3 flex flex-col gap-1"
      >
        <span class="text-label-small text-n-slate-11">
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.UNAVAILABLE.MESSAGE') }}
        </span>
        <textarea
          v-model="config.unavailable.message"
          rows="3"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
          @input="emitConfig"
        />
      </label>
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
          <select
            v-model="config.business_hours.mode"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
            @change="emitConfig"
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
          </select>
        </label>
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.TITLE')
      "
      :help-text="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.DESCRIPTION')
      "
    >
      <label class="flex items-start gap-3">
        <input
          v-model="config.supervisor_alert.enabled"
          type="checkbox"
          class="mt-1"
          @change="emitConfig"
        />
        <span class="text-body-main text-n-slate-12">
          {{
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.SUPERVISOR_ALERT.ENABLED')
          }}
        </span>
      </label>
      <label class="mt-3 flex flex-col gap-1">
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

    <div class="flex justify-end">
      <NextButton
        :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIONS.SAVE')"
        :is-loading="isLoading"
        @click="$emit('save')"
      />
    </div>
  </div>
</template>
