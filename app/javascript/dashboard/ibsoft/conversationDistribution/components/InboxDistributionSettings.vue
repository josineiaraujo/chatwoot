<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import { useAlert } from 'dashboard/composables';
import SettingsAccordion from 'dashboard/components-next/Settings/SettingsAccordion.vue';
import conversationDistributionAPI from '../api';
import { normalizePolicyConfig } from '../policyDefaults';
import DistributionPolicyForm from './DistributionPolicyForm.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const enabled = ref(false);
const config = ref(normalizePolicyConfig({}));
const isFetching = ref(false);
const isSaving = ref(false);

const teams = computed(() => store.getters['teams/getTeams'] || []);

const fetchPolicy = async () => {
  if (!props.inbox?.id) return;

  try {
    isFetching.value = true;
    const { data } = await conversationDistributionAPI.getInboxPolicy(
      props.inbox.id
    );
    enabled.value = data.enabled;
    config.value = normalizePolicyConfig(data.config);
  } finally {
    isFetching.value = false;
  }
};

const savePolicy = async () => {
  try {
    isSaving.value = true;
    const { data } = await conversationDistributionAPI.updateInboxPolicy(
      props.inbox.id,
      {
        enabled: enabled.value,
        config: config.value,
      }
    );
    enabled.value = data.enabled;
    config.value = normalizePolicyConfig(data.config);
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
  store.dispatch('teams/get');
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
      <DistributionPolicyForm
        v-else
        v-model:enabled="enabled"
        v-model="config"
        :teams="teams"
        :is-loading="isSaving"
        @save="savePolicy"
      />
    </div>
  </SettingsAccordion>
</template>
