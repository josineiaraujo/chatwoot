<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import conversationDistributionAPI from '../api';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const nativeAssignment = ref({});
const policies = ref([]);
const distributionPolicyId = ref(null);
const isFetching = ref(false);
const isSaving = ref(false);

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

const fetchPolicy = async () => {
  if (!props.inbox?.id) return;

  try {
    isFetching.value = true;
    const [{ data }, policyResponse] = await Promise.all([
      conversationDistributionAPI.getInboxPolicy(props.inbox.id),
      conversationDistributionAPI.getPolicies(),
    ]);
    policies.value = policyResponse.data.policies || [];
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
    const { data } = await conversationDistributionAPI.updateInboxPolicy(
      props.inbox.id,
      {
        distribution_policy_id: distributionPolicyId.value,
      }
    );
    distributionPolicyId.value = data.distribution_policy_id || null;
    nativeAssignment.value = data.native_assignment || {};
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => props.inbox?.id,
  () => fetchPolicy()
);

onMounted(() => {
  fetchPolicy();
});
</script>

<template>
  <SettingsAccordion
    :title="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.INBOX_SECTION.TITLE')"
    class="mt-6"
  >
    <div class="p-4">
      <p class="text-body-main text-n-slate-11 mb-4">
        {{
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.INBOX_SECTION.DESCRIPTION')
        }}
      </p>

      <div
        v-if="isFetching"
        class="rounded-xl border border-n-weak px-4 py-6 text-body-main text-n-slate-11"
      >
        {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.LOADING') }}
      </div>
      <div v-else class="space-y-4 rounded-xl border border-n-weak px-4 py-3">
        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{
              t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.SELECT')
            }}
          </span>
          <IbsoftSelect v-model="distributionPolicyId">
            <option :value="null">
              {{
                t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.POLICY_CATALOG.NONE')
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
  </SettingsAccordion>
</template>
