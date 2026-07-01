<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import conversationDistributionAPI from '../api';
import { normalizePolicyConfig } from '../policyDefaults';
import DistributionPolicyForm from './DistributionPolicyForm.vue';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  team: {
    type: Object,
    default: null,
  },
  teams: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:show']);

const { t } = useI18n();

const enabled = ref(false);
const overrideChannelPolicy = ref(false);
const config = ref(normalizePolicyConfig({}));
const sourceTeamId = ref(null);
const isFetching = ref(false);
const isSaving = ref(false);
const isCopying = ref(false);

const showProxy = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const availableSourceTeams = computed(() =>
  props.teams.filter(team => team.id !== props.team?.id)
);

const close = () => {
  showProxy.value = false;
};

const fetchPolicy = async () => {
  if (!props.show || !props.team?.id) return;

  try {
    isFetching.value = true;
    const { data } = await conversationDistributionAPI.getTeamPolicy(
      props.team.id
    );
    enabled.value = data.enabled;
    overrideChannelPolicy.value = data.override_channel_policy;
    config.value = normalizePolicyConfig(data.config);
  } finally {
    isFetching.value = false;
  }
};

const savePolicy = async () => {
  try {
    isSaving.value = true;
    const { data } = await conversationDistributionAPI.updateTeamPolicy(
      props.team.id,
      {
        enabled: enabled.value,
        override_channel_policy: overrideChannelPolicy.value,
        config: config.value,
      }
    );
    enabled.value = data.enabled;
    overrideChannelPolicy.value = data.override_channel_policy;
    config.value = normalizePolicyConfig(data.config);
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_SUCCESS'));
  } catch (error) {
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const copyPolicy = async () => {
  if (!sourceTeamId.value || !props.team?.id) return;

  try {
    isCopying.value = true;
    const { data } = await conversationDistributionAPI.copyTeamPolicy({
      source_team_id: sourceTeamId.value,
      target_team_id: props.team.id,
    });
    enabled.value = data.enabled;
    overrideChannelPolicy.value = data.override_channel_policy;
    config.value = normalizePolicyConfig(data.config);
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.COPY_SUCCESS'));
  } catch (error) {
    useAlert(t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.COPY_ERROR'));
  } finally {
    isCopying.value = false;
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
        <div class="mb-5 rounded-xl border border-n-weak px-4 py-3">
          <label class="flex flex-col gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.COPY.LABEL') }}
            </span>
            <div class="flex flex-col gap-2 md:flex-row">
              <select
                v-model.number="sourceTeamId"
                class="min-w-0 flex-1 rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-n-slate-12"
              >
                <option :value="null">
                  {{
                    t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.COPY.PLACEHOLDER')
                  }}
                </option>
                <option
                  v-for="sourceTeam in availableSourceTeams"
                  :key="sourceTeam.id"
                  :value="sourceTeam.id"
                >
                  {{ sourceTeam.name }}
                </option>
              </select>
              <NextButton
                :label="t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.COPY.BUTTON')"
                icon="i-lucide-copy"
                slate
                faded
                :disabled="!sourceTeamId"
                :is-loading="isCopying"
                @click="copyPolicy"
              />
            </div>
          </label>
        </div>

        <div
          v-if="isFetching"
          class="rounded-xl border border-n-weak px-4 py-6 text-body-main text-n-slate-11"
        >
          {{ t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.API.LOADING') }}
        </div>
        <DistributionPolicyForm
          v-else
          v-model:enabled="enabled"
          v-model:override-channel-policy="overrideChannelPolicy"
          v-model="config"
          is-team-policy
          :teams="teams"
          :is-loading="isSaving"
          @save="savePolicy"
        />
      </div>
    </div>
  </woot-modal>
</template>
