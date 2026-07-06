<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  team: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['update:show']);

const { t } = useI18n();

const overrideChannelPolicy = ref(false);
const nativeAssignment = ref({});
const policies = ref([]);
const distributionPolicyId = ref(null);
const isFetching = ref(false);
const isSaving = ref(false);

const showProxy = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const activationWarnings = computed(() => {
  if (!nativeAssignment.value?.team_auto_assignment_enabled) {
    return [];
  }

  return ['TEAM_AUTO_ASSIGNMENT'];
});
const activationWarningLabels = computed(() => ({
  TEAM_AUTO_ASSIGNMENT: t(
    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIVATION_ALERT.ITEMS.TEAM_AUTO_ASSIGNMENT'
  ),
}));

const close = () => {
  showProxy.value = false;
};

const fetchPolicy = async () => {
  if (!props.show || !props.team?.id) return;

  try {
    isFetching.value = true;
    const [{ data }, policyResponse] = await Promise.all([
      conversationDistributionAPI.getTeamPolicy(props.team.id),
      conversationDistributionAPI.getPolicies(),
    ]);
    policies.value = policyResponse.data.policies || [];
    overrideChannelPolicy.value = data.override_channel_policy;
    distributionPolicyId.value = data.distribution_policy_id || null;
    nativeAssignment.value = data.native_assignment || {};
  } finally {
    isFetching.value = false;
  }
};

const selectedPolicy = computed(
  () =>
    policies.value.find(
      policy => policy.id === Number(distributionPolicyId.value)
    ) || null
);

const savePolicy = async () => {
  try {
    isSaving.value = true;
    const { data } = await conversationDistributionAPI.updateTeamPolicy(
      props.team.id,
      {
        override_channel_policy: overrideChannelPolicy.value,
        distribution_policy_id: distributionPolicyId.value,
      }
    );
    distributionPolicyId.value = data.distribution_policy_id || null;
    overrideChannelPolicy.value = data.override_channel_policy;
    nativeAssignment.value = data.native_assignment || {};
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_SUCCESS'));
    close();
  } catch (error) {
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => [props.show, props.team?.id],
  () => fetchPolicy(),
  { immediate: true }
);
</script>

<template>
  <woot-modal v-model:show="showProxy" :on-close="close">
    <div class="flex max-h-[88vh] w-full max-w-5xl flex-col overflow-hidden">
      <woot-modal-header
        :header-title="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TEAM_MODAL.TITLE', {
            teamName: team?.name,
          })
        "
        :header-content="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.TEAM_MODAL.DESCRIPTION')
        "
      />

      <div class="overflow-y-auto px-6 pb-6">
        <div
          v-if="isFetching"
          class="rounded-xl border border-n-weak px-4 py-6 text-body-main text-n-slate-11"
        >
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.LOADING') }}
        </div>
        <div v-else class="space-y-4 rounded-xl border border-n-weak px-4 py-3">
          <div
            class="flex items-center justify-between gap-4 rounded-lg border border-n-weak px-3 py-2"
          >
            <div class="min-w-0">
              <h4 class="mb-0.5 text-heading-3 text-n-slate-12">
                {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.TITLE') }}
              </h4>
              <p class="mb-0 text-body-main text-n-slate-11">
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.OVERRIDE.DESCRIPTION'
                  )
                }}
              </p>
            </div>
            <ToggleSwitch v-model="overrideChannelPolicy" />
          </div>

          <label v-if="overrideChannelPolicy" class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.SELECT'
                )
              }}
            </span>
            <IbsoftSelect v-model="distributionPolicyId">
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

          <ul
            v-if="activationWarnings.length"
            class="mb-0 list-disc rounded-lg border border-n-weak px-6 py-3 text-body-small text-n-slate-11"
          >
            <li v-for="warning in activationWarnings" :key="warning">
              {{ activationWarningLabels[warning] || warning }}
            </li>
          </ul>

          <div class="flex justify-end">
            <Button
              :label="
                t(
                  'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.SAVE_LINK'
                )
              "
              icon="i-lucide-link"
              :is-loading="isSaving"
              @click="savePolicy"
            />
          </div>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
