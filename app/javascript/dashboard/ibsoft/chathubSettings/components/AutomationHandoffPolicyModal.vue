<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from 'dashboard/ibsoft/conversationDistribution/api';

const props = defineProps({
  teams: {
    type: Array,
    default: () => [],
  },
});

const ACTION_FORWARD_TO_TEAM = 'forward_to_team';
const ACTION_CLOSE_CONVERSATION = 'close_conversation';

const { t } = useI18n();
const store = useStore();

const dialogRef = ref(null);
const inbox = ref(null);
const activeTab = ref('distribution');
const isAutomationFetching = ref(false);
const isDistributionFetching = ref(false);
const isSaving = ref(false);
const isNativeAssignmentDisabling = ref(false);
const nativeAssignmentDisableFailed = ref(false);
const automationLoaded = ref(false);
const distributionLoaded = ref(false);
const policies = ref([]);
const nativeAssignment = ref({});
const distributionPolicyId = ref(null);
const form = ref({
  enabled: false,
  stale_after_minutes: 10,
  timeout_action: ACTION_FORWARD_TO_TEAM,
  target_team_id: null,
  customer_message_enabled: false,
  customer_message: '',
  close_warning_enabled: false,
  close_warning_message: '',
  close_warning_delay_minutes: 1,
  close_final_message_enabled: false,
  close_final_message: '',
});

const dialogTitle = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TITLE', {
    inbox: inbox.value?.name || '',
  })
);

const tabs = computed(() => [
  {
    id: 'distribution',
    label: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TABS.DISTRIBUTION'
    ),
  },
  {
    id: 'automation',
    label: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TABS.AUTOMATION'
    ),
  },
]);

const isFetching = computed(
  () => isAutomationFetching.value || isDistributionFetching.value
);

const isInvalid = computed(() => {
  if (!form.value.enabled) return false;

  const staleMinutes = Number(form.value.stale_after_minutes);
  const warningDelayMinutes = Number(form.value.close_warning_delay_minutes);
  const hasInvalidWarningDelay =
    form.value.timeout_action === ACTION_CLOSE_CONVERSATION &&
    form.value.close_warning_enabled &&
    (!Number.isFinite(warningDelayMinutes) ||
      warningDelayMinutes < 1 ||
      warningDelayMinutes > 1440);

  return (
    (form.value.timeout_action === ACTION_FORWARD_TO_TEAM &&
      !form.value.target_team_id) ||
    !Number.isFinite(staleMinutes) ||
    staleMinutes < 1 ||
    hasInvalidWarningDelay
  );
});

const timeoutActions = computed(() => [
  {
    id: ACTION_FORWARD_TO_TEAM,
    icon: 'i-lucide-users-round',
    title: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTIONS.FORWARD.TITLE'
    ),
    description: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTIONS.FORWARD.DESCRIPTION'
    ),
  },
  {
    id: ACTION_CLOSE_CONVERSATION,
    icon: 'i-lucide-circle-check-big',
    title: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTIONS.CLOSE.TITLE'
    ),
    description: t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTIONS.CLOSE.DESCRIPTION'
    ),
  },
]);

const internalEventNotice = computed(() => {
  if (form.value.timeout_action === ACTION_CLOSE_CONVERSATION) {
    return t(
      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.INTERNAL_EVENT_NOTICE_CLOSE'
    );
  }

  return t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.INTERNAL_EVENT_NOTICE_FORWARD'
  );
});

const selectedPolicy = computed(
  () =>
    policies.value.find(
      policy => policy.id === Number(distributionPolicyId.value)
    ) || null
);

const isNativeAutoAssignmentEnabled = computed(() =>
  Boolean(
    inbox.value?.enable_auto_assignment ||
      nativeAssignment.value?.inbox_auto_assignment_enabled
  )
);

const nativeAssignmentStatus = computed(() => {
  if (nativeAssignmentDisableFailed.value) return 'failed';
  if (isNativeAssignmentDisabling.value) return 'disabling';
  return isNativeAutoAssignmentEnabled.value ? 'active' : 'disabled';
});

const nativeAssignmentIndicatorLabels = computed(() => ({
  active: t('IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT.INDICATOR.ACTIVE'),
  disabling: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT.INDICATOR.DISABLING'
  ),
  disabled: t(
    'IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT.INDICATOR.DISABLED'
  ),
  failed: t('IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT.INDICATOR.FAILED'),
}));

const nativeAssignmentIndicatorLabel = computed(
  () => nativeAssignmentIndicatorLabels.value[nativeAssignmentStatus.value]
);

const nativeAssignmentIndicatorClasses = computed(() => ({
  'border-n-ruby-5 bg-n-ruby-9': ['active', 'failed'].includes(
    nativeAssignmentStatus.value
  ),
  'border-n-amber-5 bg-n-amber-9 animate-pulse':
    nativeAssignmentStatus.value === 'disabling',
  'border-n-teal-5 bg-n-teal-9': nativeAssignmentStatus.value === 'disabled',
}));

const activationWarnings = computed(() => {
  const warnings = [];

  if (nativeAssignment.value?.inbox_auto_assignment_enabled) {
    warnings.push('CHANNEL_AUTO_ASSIGNMENT');
  }

  if (
    nativeAssignment.value?.assignment_policy_id &&
    nativeAssignment.value?.inbox_auto_assignment_enabled
  ) {
    warnings.push('ASSIGNMENT_POLICY');
  }

  return warnings;
});

const activationWarningLabels = computed(() => ({
  CHANNEL_AUTO_ASSIGNMENT: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.CHANNEL_AUTO_ASSIGNMENT'
  ),
  ASSIGNMENT_POLICY: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.ASSIGNMENT_POLICY'
  ),
}));

const isSaveDisabled = computed(
  () =>
    isSaving.value ||
    isFetching.value ||
    isInvalid.value ||
    !automationLoaded.value ||
    !distributionLoaded.value
);

const resetForm = () => {
  form.value = {
    enabled: false,
    stale_after_minutes: 10,
    timeout_action: ACTION_FORWARD_TO_TEAM,
    target_team_id: null,
    customer_message_enabled: false,
    customer_message: '',
    close_warning_enabled: false,
    close_warning_message: '',
    close_warning_delay_minutes: 1,
    close_final_message_enabled: false,
    close_final_message: '',
  };
};

const resetDistribution = () => {
  policies.value = [];
  nativeAssignment.value = {};
  distributionPolicyId.value = null;
  nativeAssignmentDisableFailed.value = false;
  isNativeAssignmentDisabling.value = false;
};

const applyAutomationPolicy = policy => {
  form.value = {
    enabled: Boolean(policy.enabled),
    stale_after_minutes: policy.stale_after_minutes || 10,
    timeout_action: policy.timeout_action || ACTION_FORWARD_TO_TEAM,
    target_team_id: policy.target_team_id || null,
    customer_message_enabled: Boolean(policy.customer_message_enabled),
    customer_message: policy.customer_message || '',
    close_warning_enabled: Boolean(policy.close_warning_enabled),
    close_warning_message: policy.close_warning_message || '',
    close_warning_delay_minutes: policy.close_warning_delay_minutes || 1,
    close_final_message_enabled: Boolean(policy.close_final_message_enabled),
    close_final_message: policy.close_final_message || '',
  };
};

const fetchAutomationPolicy = async () => {
  if (!inbox.value?.id) return;

  isAutomationFetching.value = true;
  automationLoaded.value = false;
  try {
    const { data } =
      await conversationDistributionAPI.getAutomationHandoffPolicy(
        inbox.value.id
      );
    applyAutomationPolicy(data);
    automationLoaded.value = true;
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.LOAD_ERROR'));
  } finally {
    isAutomationFetching.value = false;
  }
};

async function disableNativeAutoAssignment() {
  if (
    !inbox.value?.id ||
    !isNativeAutoAssignmentEnabled.value ||
    isNativeAssignmentDisabling.value
  ) {
    return;
  }

  isNativeAssignmentDisabling.value = true;
  nativeAssignmentDisableFailed.value = false;

  try {
    await store.dispatch('inboxes/updateInbox', {
      id: inbox.value.id,
      formData: false,
      enable_auto_assignment: false,
    });
    inbox.value = { ...inbox.value, enable_auto_assignment: false };
    nativeAssignment.value = {
      ...nativeAssignment.value,
      inbox_auto_assignment_enabled: false,
    };
  } catch {
    nativeAssignmentDisableFailed.value = true;
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.NATIVE_ASSIGNMENT.DISABLE_ERROR')
    );
  } finally {
    isNativeAssignmentDisabling.value = false;
  }
}

const fetchDistributionPolicy = async () => {
  if (!inbox.value?.id) return;

  isDistributionFetching.value = true;
  distributionLoaded.value = false;
  try {
    const [{ data }, policyResponse] = await Promise.all([
      conversationDistributionAPI.getInboxPolicy(inbox.value.id),
      conversationDistributionAPI.getPolicies(),
    ]);
    policies.value = policyResponse.data.policies || [];
    distributionPolicyId.value = data.distribution_policy_id || null;
    nativeAssignment.value = data.native_assignment || {};
    disableNativeAutoAssignment();
    distributionLoaded.value = true;
  } catch {
    useAlert(
      t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.DISTRIBUTION_LOAD_ERROR'
      )
    );
  } finally {
    isDistributionFetching.value = false;
  }
};

const open = async selectedInbox => {
  inbox.value = selectedInbox;
  activeTab.value = 'distribution';
  resetForm();
  resetDistribution();
  automationLoaded.value = false;
  distributionLoaded.value = false;
  await nextTick();
  dialogRef.value?.open();
  disableNativeAutoAssignment();
  fetchDistributionPolicy();
  fetchAutomationPolicy();
};

const close = () => {
  inbox.value = null;
  resetForm();
  resetDistribution();
  automationLoaded.value = false;
  distributionLoaded.value = false;
};

const numberValue = event => {
  const value = Number(event.target.value);
  form.value.stale_after_minutes =
    Number.isFinite(value) && value > 0 ? value : 1;
};

const closeWarningDelayValue = event => {
  const value = Number(event.target.value);
  form.value.close_warning_delay_minutes = Number.isFinite(value) ? value : 1;
};

const selectTimeoutAction = action => {
  form.value.timeout_action = action;
  if (action === ACTION_CLOSE_CONVERSATION) {
    form.value.target_team_id = null;
  }
};

const saveDistributionPolicy = async () => {
  const { data } = await conversationDistributionAPI.updateInboxPolicy(
    inbox.value.id,
    {
      distribution_policy_id: distributionPolicyId.value,
    }
  );
  distributionPolicyId.value = data.distribution_policy_id || null;
  nativeAssignment.value = data.native_assignment || {};
};

const saveAutomationPolicy = async () => {
  const { data } =
    await conversationDistributionAPI.updateAutomationHandoffPolicy(
      inbox.value.id,
      {
        enabled: form.value.enabled,
        stale_after_minutes: form.value.stale_after_minutes,
        timeout_action: form.value.timeout_action,
        target_team_id:
          form.value.timeout_action === ACTION_FORWARD_TO_TEAM
            ? form.value.target_team_id
            : null,
        customer_message_enabled: form.value.customer_message_enabled,
        customer_message: form.value.customer_message,
        close_warning_enabled: form.value.close_warning_enabled,
        close_warning_message: form.value.close_warning_message,
        close_warning_delay_minutes: form.value.close_warning_delay_minutes,
        close_final_message_enabled: form.value.close_final_message_enabled,
        close_final_message: form.value.close_final_message,
      }
    );
  applyAutomationPolicy(data);
};

const saveSettings = async () => {
  if (!inbox.value?.id || isSaveDisabled.value) return;

  isSaving.value = true;
  try {
    await Promise.all([saveDistributionPolicy(), saveAutomationPolicy()]);
    dialogRef.value?.close();
    useAlert(
      t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.SAVE_SUCCESS')
    );
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    position="top"
    overflow-y-auto
    :title="dialogTitle"
    :confirm-button-label="
      t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.SAVE')
    "
    :disable-confirm-button="isSaveDisabled"
    :is-loading="isSaving"
    @confirm="saveSettings"
    @close="close"
  >
    <div
      class="flex gap-1 rounded-lg bg-n-alpha-1 p-1"
      role="tablist"
      :aria-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TABS_LABEL')
      "
    >
      <Button
        v-for="tab in tabs"
        :key="tab.id"
        :label="tab.label"
        size="sm"
        type="button"
        :variant="activeTab === tab.id ? 'solid' : 'ghost'"
        :color="activeTab === tab.id ? 'blue' : 'slate'"
        class="flex-1 justify-center"
        role="tab"
        :aria-selected="activeTab === tab.id"
        @click="activeTab = tab.id"
      />
    </div>

    <div v-if="activeTab === 'distribution'" class="space-y-5" role="tabpanel">
      <div
        v-if="isDistributionFetching"
        class="grid min-h-48 place-content-center"
      >
        <Spinner />
      </div>

      <template v-else>
        <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.DISTRIBUTION_TITLE'
                  )
                }}
              </h3>
              <p class="mb-0 text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.DISTRIBUTION_DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <span
              class="mt-1 size-3 shrink-0 rounded-full border"
              :class="nativeAssignmentIndicatorClasses"
              role="status"
              :aria-label="nativeAssignmentIndicatorLabel"
            />
          </div>
        </section>

        <section
          class="space-y-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.SELECT'
                )
              }}
            </span>
            <IbsoftSelect
              v-model="distributionPolicyId"
              class="automation-handoff-select"
            >
              <option :value="null">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.NONE'
                  )
                }}
              </option>
              <option
                v-for="policy in policies"
                :key="policy.id"
                :value="policy.id"
              >
                {{ policy.name }}
              </option>
            </IbsoftSelect>
          </label>

          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              selectedPolicy
                ? t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.LINK_HELP'
                  )
                : t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.EMPTY_LINK'
                  )
            }}
          </p>

          <p
            class="mb-0 rounded-lg bg-n-alpha-1 px-3 py-2 text-body-small text-n-slate-11"
          >
            {{
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.TEAM_OVERRIDE_NOTICE'
              )
            }}
          </p>

          <ul
            v-if="activationWarnings.length"
            class="mb-0 list-disc rounded-lg border border-n-weak px-6 py-3 text-body-small text-n-slate-11"
          >
            <li v-for="warning in activationWarnings" :key="warning">
              {{ activationWarningLabels[warning] || warning }}
            </li>
          </ul>
        </section>
      </template>
    </div>

    <div v-else class="space-y-5" role="tabpanel">
      <div
        v-if="isAutomationFetching"
        class="grid min-h-48 place-content-center"
      >
        <Spinner />
      </div>

      <template v-else>
        <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
          <div class="flex items-start justify-between gap-4">
            <div>
              <h3 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ENABLE_TITLE'
                  )
                }}
              </h3>
              <p class="mb-0 text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ENABLE_DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <ToggleSwitch v-model="form.enabled" class="shrink-0" />
          </div>
        </section>

        <section v-if="form.enabled" class="space-y-3">
          <h3 class="mb-0 text-heading-3 text-n-slate-12">
            {{
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTION_TITLE')
            }}
          </h3>
          <div
            class="grid gap-3 md:grid-cols-2"
            role="radiogroup"
            :aria-label="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.ACTION_TITLE')
            "
          >
            <button
              v-for="action in timeoutActions"
              :key="action.id"
              type="button"
              class="flex min-h-24 items-start gap-3 rounded-lg border p-4 text-left transition-colors"
              :class="
                form.timeout_action === action.id
                  ? 'border-n-brand bg-n-alpha-2'
                  : 'border-n-weak bg-n-alpha-1 hover:bg-n-alpha-2'
              "
              role="radio"
              :aria-checked="form.timeout_action === action.id"
              :data-testid="`automation-action-${action.id}`"
              @click="selectTimeoutAction(action.id)"
            >
              <span
                class="mt-0.5 size-5 shrink-0 text-n-brand"
                :class="action.icon"
              />
              <span class="min-w-0">
                <span class="block text-label-medium text-n-slate-12">
                  {{ action.title }}
                </span>
                <span class="mt-1 block text-body-small text-n-slate-11">
                  {{ action.description }}
                </span>
              </span>
            </button>
          </div>
        </section>

        <div
          v-if="form.enabled"
          class="grid items-start gap-4"
          :class="
            form.timeout_action === ACTION_FORWARD_TO_TEAM
              ? 'md:grid-cols-2'
              : 'md:grid-cols-1'
          "
        >
          <label
            class="grid content-start gap-1"
            data-testid="automation-stale-after"
          >
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.STALE_AFTER'
                )
              }}
            </span>
            <div class="grid grid-cols-[minmax(0,1fr)_8rem] items-start gap-2">
              <input
                :value="form.stale_after_minutes"
                type="number"
                min="1"
                class="h-10 min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
                @input="numberValue"
              />
              <span
                class="grid h-10 min-h-10 place-items-center rounded-lg bg-n-alpha-2 px-3 text-sm text-n-slate-11"
              >
                {{
                  t('IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.MINUTES')
                }}
              </span>
            </div>
          </label>

          <label
            v-if="form.timeout_action === ACTION_FORWARD_TO_TEAM"
            class="grid content-start gap-1"
            data-testid="automation-target-team"
          >
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.TARGET_TEAM'
                )
              }}
            </span>
            <IbsoftSelect
              v-model="form.target_team_id"
              class="automation-handoff-select"
            >
              <option :value="null">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.SELECT_TEAM'
                  )
                }}
              </option>
              <option
                v-for="team in props.teams"
                :key="team.id"
                :value="team.id"
              >
                {{ team.name }}
              </option>
            </IbsoftSelect>
          </label>
        </div>

        <p
          v-if="form.enabled"
          class="mb-0 rounded-lg bg-n-alpha-1 px-3 py-2 text-body-small text-n-slate-11"
        >
          {{ internalEventNotice }}
        </p>

        <section
          v-if="form.enabled && form.timeout_action === ACTION_FORWARD_TO_TEAM"
          class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
          data-testid="automation-forward-message"
        >
          <div class="mb-3 flex items-start justify-between gap-4">
            <div>
              <h3 class="mb-1 text-heading-3 text-n-slate-12">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CUSTOMER_MESSAGE_TITLE'
                  )
                }}
              </h3>
              <p class="mb-0 text-body-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CUSTOMER_MESSAGE_DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <ToggleSwitch
              v-model="form.customer_message_enabled"
              class="shrink-0"
            />
          </div>

          <label v-if="form.customer_message_enabled" class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CUSTOMER_MESSAGE'
                )
              }}
            </span>
            <textarea
              v-model="form.customer_message"
              rows="4"
              class="resize-y rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
              :placeholder="
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CUSTOMER_MESSAGE_PLACEHOLDER_FORWARD'
                )
              "
            />
          </label>
        </section>

        <template
          v-if="
            form.enabled && form.timeout_action === ACTION_CLOSE_CONVERSATION
          "
        >
          <section
            class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
            data-testid="automation-close-warning"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <h3 class="mb-1 text-heading-3 text-n-slate-12">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_WARNING_TITLE'
                    )
                  }}
                </h3>
                <p class="mb-0 text-body-small text-n-slate-11">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_WARNING_DESCRIPTION'
                    )
                  }}
                </p>
              </div>
              <ToggleSwitch
                v-model="form.close_warning_enabled"
                class="shrink-0"
              />
            </div>

            <div v-if="form.close_warning_enabled" class="mt-4 grid gap-4">
              <label class="grid max-w-md gap-1">
                <span class="text-label-small text-n-slate-11">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_WARNING_DELAY'
                    )
                  }}
                </span>
                <div
                  class="grid grid-cols-[minmax(0,1fr)_8rem] items-start gap-2"
                >
                  <input
                    :value="form.close_warning_delay_minutes"
                    type="number"
                    min="1"
                    max="1440"
                    class="h-10 min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
                    data-testid="automation-close-warning-delay"
                    @input="closeWarningDelayValue"
                  />
                  <span
                    class="grid h-10 min-h-10 place-items-center rounded-lg bg-n-alpha-2 px-3 text-sm text-n-slate-11"
                  >
                    {{
                      t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.MINUTES'
                      )
                    }}
                  </span>
                </div>
              </label>

              <label class="grid gap-1">
                <span class="text-label-small text-n-slate-11">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_WARNING_MESSAGE'
                    )
                  }}
                </span>
                <textarea
                  v-model="form.close_warning_message"
                  rows="3"
                  class="resize-y rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                  :placeholder="
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_WARNING_MESSAGE_PLACEHOLDER'
                    )
                  "
                />
              </label>
            </div>
          </section>

          <section
            class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
            data-testid="automation-close-final-message"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <h3 class="mb-1 text-heading-3 text-n-slate-12">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_FINAL_MESSAGE_TITLE'
                    )
                  }}
                </h3>
                <p class="mb-0 text-body-small text-n-slate-11">
                  {{
                    t(
                      'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_FINAL_MESSAGE_DESCRIPTION'
                    )
                  }}
                </p>
              </div>
              <ToggleSwitch
                v-model="form.close_final_message_enabled"
                class="shrink-0"
              />
            </div>

            <label
              v-if="form.close_final_message_enabled"
              class="mt-4 grid gap-1"
            >
              <span class="text-label-small text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_FINAL_MESSAGE'
                  )
                }}
              </span>
              <textarea
                v-model="form.close_final_message"
                rows="3"
                class="resize-y rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
                :placeholder="
                  t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.AUTOMATION_HANDOFF.CLOSE_FINAL_MESSAGE_PLACEHOLDER'
                  )
                "
              />
            </label>
          </section>
        </template>
      </template>
    </div>
  </Dialog>
</template>

<style scoped>
.automation-handoff-select :deep(select) {
  height: 2.5rem;
  min-height: 2.5rem;
  margin: 0 !important;
}
</style>
