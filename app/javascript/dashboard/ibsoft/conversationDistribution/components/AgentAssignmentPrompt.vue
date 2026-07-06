<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';

import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import conversationDistributionAPI from '../api';

const AGENT_ASSIGNMENT_PREVIEW_LIMIT = 100;

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const show = ref(false);
const isFetching = ref(false);
const isClaiming = ref(false);
const hasFetchedForCurrentOnlineSession = ref(false);
const candidates = ref([]);
const selectedConversationIds = ref([]);
const agentEntryAssignment = ref({});

const currentAvailability = computed(
  () => store.getters.getCurrentUserAvailability
);
const requiredConversationIds = computed(() =>
  candidates.value
    .filter(candidate => candidate.required)
    .map(candidate => candidate.conversation_id)
);
const hasRequiredAssignments = computed(
  () => requiredConversationIds.value.length > 0
);
const shouldBlockCloseWhenRequired = computed(
  () => agentEntryAssignment.value?.block_close_when_required !== false
);
const canClaim = computed(
  () =>
    selectedConversationIds.value.length > 0 &&
    requiredConversationIds.value.every(id =>
      selectedConversationIds.value.includes(id)
    )
);

const contactName = candidate =>
  candidate.contact?.name ||
  candidate.contact?.email ||
  candidate.contact?.phone_number ||
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.UNKNOWN_CUSTOMER');

const formatWaiting = candidate =>
  t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.WAITING_MINUTES', {
    count: candidate.minutes_waiting || 0,
  });

const candidateMeta = candidate =>
  [
    candidate.display_id ? `#${candidate.display_id}` : null,
    candidate.team_name,
    candidate.inbox_name,
  ]
    .filter(Boolean)
    .join(' · ');

const toggleSelection = candidate => {
  if (candidate.required) return;

  if (selectedConversationIds.value.includes(candidate.conversation_id)) {
    selectedConversationIds.value = selectedConversationIds.value.filter(
      id => id !== candidate.conversation_id
    );
    return;
  }

  selectedConversationIds.value = [
    ...selectedConversationIds.value,
    candidate.conversation_id,
  ];
};

const closePrompt = () => {
  if (hasRequiredAssignments.value && shouldBlockCloseWhenRequired.value) {
    useAlert(
      t(
        'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.REQUIRED_NOTICE'
      )
    );
    return;
  }

  show.value = false;
};

const openConversation = result => {
  if (!result?.display_id) return;

  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: result.display_id,
    },
  });
};

const claim = async conversationIds => {
  if (!conversationIds.length) return;

  isClaiming.value = true;
  try {
    const { data } =
      await conversationDistributionAPI.claimAgentAssignments(conversationIds);
    const assigned =
      data.results?.filter(result => result.status === 'assigned') || [];
    useAlert(
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.CLAIM_SUCCESS')
    );
    show.value = false;
    candidates.value = [];
    selectedConversationIds.value = [];
    openConversation(assigned[0]);
  } catch {
    useAlert(
      t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.CLAIM_ERROR')
    );
  } finally {
    isClaiming.value = false;
  }
};

const fetchAssignments = async () => {
  if (currentAvailability.value !== 'online' || isFetching.value) return;

  isFetching.value = true;
  try {
    const { data } = await conversationDistributionAPI.getAgentAssignments({
      limit: AGENT_ASSIGNMENT_PREVIEW_LIMIT,
    });

    if (!data.real_assignment_enabled) {
      show.value = false;
      candidates.value = [];
      agentEntryAssignment.value = data.agent_entry_assignment || {};
      return;
    }

    if (data.auto_claim_conversation_ids?.length) {
      await claim(data.auto_claim_conversation_ids);
      return;
    }

    candidates.value = data.candidates || [];
    agentEntryAssignment.value = data.agent_entry_assignment || {};
    selectedConversationIds.value = candidates.value
      .filter(candidate => candidate.preselected)
      .map(candidate => candidate.conversation_id);
    show.value = candidates.value.length > 0;
  } catch {
    candidates.value = [];
    agentEntryAssignment.value = {};
    show.value = false;
  } finally {
    isFetching.value = false;
    hasFetchedForCurrentOnlineSession.value = true;
  }
};

watch(
  currentAvailability,
  availability => {
    if (availability !== 'online') {
      hasFetchedForCurrentOnlineSession.value = false;
      show.value = false;
      return;
    }

    if (!hasFetchedForCurrentOnlineSession.value) {
      fetchAssignments();
    }
  },
  { immediate: true }
);

onMounted(fetchAssignments);
</script>

<template>
  <woot-modal :show="show" :on-close="closePrompt">
    <div class="flex max-h-[84vh] w-full max-w-3xl flex-col overflow-hidden">
      <woot-modal-header
        :header-title="
          t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.TITLE')
        "
        :header-content="
          t(
            'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.DESCRIPTION'
          )
        "
      />

      <div class="min-h-0 overflow-y-auto px-6 pb-6">
        <div v-if="isFetching" class="grid min-h-52 place-content-center">
          <Spinner />
        </div>

        <div v-else class="space-y-3">
          <button
            v-for="candidate in candidates"
            :key="candidate.conversation_id"
            type="button"
            class="flex w-full items-start gap-3 rounded-xl border border-n-weak bg-n-alpha-1 p-3 text-start transition-colors hover:bg-n-alpha-2"
            @click="toggleSelection(candidate)"
          >
            <input
              type="checkbox"
              class="mt-1"
              :checked="
                selectedConversationIds.includes(candidate.conversation_id)
              "
              :disabled="candidate.required"
              @click.stop
              @change="toggleSelection(candidate)"
            />
            <div class="min-w-0 flex-1">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="mb-0 truncate text-heading-3 text-n-slate-12">
                    {{ contactName(candidate) }}
                  </p>
                  <p class="mb-0 text-label-small text-n-slate-11">
                    {{ candidateMeta(candidate) }}
                  </p>
                </div>
                <span class="shrink-0 text-label-small text-n-slate-11">
                  {{ formatWaiting(candidate) }}
                </span>
              </div>
              <p
                v-if="candidate.required"
                class="mb-0 mt-2 text-label-small text-n-amber-11"
              >
                {{
                  t(
                    'IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.REQUIRED'
                  )
                }}
              </p>
            </div>
          </button>
        </div>
      </div>

      <div class="flex justify-end gap-2 border-t border-n-weak px-6 py-4">
        <Button
          v-if="!hasRequiredAssignments"
          :label="
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.LATER')
          "
          slate
          faded
          @click="closePrompt"
        />
        <Button
          :label="
            t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.AGENT_ASSIGNMENT.CLAIM')
          "
          :disabled="!canClaim"
          :is-loading="isClaiming"
          @click="claim(selectedConversationIds)"
        />
      </div>
    </div>
  </woot-modal>
</template>
