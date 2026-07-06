<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import conversationDistributionAPI from 'dashboard/ibsoft/conversationDistribution/api';
import DistributionPolicyForm from 'dashboard/ibsoft/conversationDistribution/components/DistributionPolicyForm.vue';
import { normalizePolicyConfig } from 'dashboard/ibsoft/conversationDistribution/policyDefaults';
import DistributionPolicyCard from './DistributionPolicyCard.vue';

const { t } = useI18n();
const store = useStore();

const policies = ref([]);
const editingPolicyId = ref(null);
const policyName = ref('');
const enabled = ref(false);
const config = ref(normalizePolicyConfig({}));
const isFetching = ref(false);
const isSaving = ref(false);
const isDeleting = ref(false);
const isCreating = ref(false);
const policyToDelete = ref(null);
const policyDialogRef = ref(null);
const deleteDialogRef = ref(null);

const teams = computed(() => store.getters['teams/getTeams'] || []);
const editingPolicy = computed(() =>
  policies.value.find(policy => policy.id === Number(editingPolicyId.value))
);
const dialogTitle = computed(() =>
  isCreating.value
    ? t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.CREATE_TITLE')
    : t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.EDIT_TITLE')
);
const isPolicyNameBlank = computed(() => !policyName.value.trim());
const selectedPolicyUsage = computed(() => {
  if (!editingPolicy.value) return null;

  return t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.USAGE', {
    channels: editingPolicy.value.linked_channels_count || 0,
    teams: editingPolicy.value.linked_teams_count || 0,
  });
});

const resetEditor = () => {
  editingPolicyId.value = null;
  policyName.value = '';
  enabled.value = false;
  config.value = normalizePolicyConfig({});
  isCreating.value = false;
};

const applyPolicy = policy => {
  editingPolicyId.value = policy.id;
  policyName.value = policy.name;
  enabled.value = policy.enabled;
  config.value = normalizePolicyConfig(policy.config || {});
  isCreating.value = false;
};

const fetchPolicies = async () => {
  isFetching.value = true;
  try {
    const { data } = await conversationDistributionAPI.getPolicies();
    policies.value = data.policies || [];

    if (editingPolicyId.value && editingPolicy.value) {
      applyPolicy(editingPolicy.value);
    }
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.POLICIES_LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const openPolicyDialog = async () => {
  await nextTick();
  policyDialogRef.value?.open();
};

const openCreatePolicy = () => {
  editingPolicyId.value = null;
  policyName.value = t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.NEW_NAME');
  enabled.value = false;
  config.value = normalizePolicyConfig({});
  isCreating.value = true;
  openPolicyDialog();
};

const openEditPolicy = policyId => {
  const policy = policies.value.find(item => item.id === Number(policyId));
  if (!policy) return;

  applyPolicy(policy);
  openPolicyDialog();
};

const savePolicy = async () => {
  isSaving.value = true;
  try {
    const payload = {
      name: policyName.value,
      enabled: enabled.value,
      config: config.value,
    };
    const { data } = isCreating.value
      ? await conversationDistributionAPI.createPolicy(payload)
      : await conversationDistributionAPI.updatePolicy(
          editingPolicyId.value,
          payload
        );

    editingPolicyId.value = data.id;
    await fetchPolicies();
    policyDialogRef.value?.close();
    resetEditor();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.SAVED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.POLICIES_SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const openDeletePolicy = policyId => {
  policyToDelete.value = policies.value.find(
    policy => policy.id === Number(policyId)
  );
  if (!policyToDelete.value) return;

  deleteDialogRef.value?.open();
};

const closeDeletePolicy = () => {
  policyToDelete.value = null;
  deleteDialogRef.value?.close();
};

const confirmDeletePolicy = async () => {
  if (!policyToDelete.value) return;

  isDeleting.value = true;
  try {
    const deletedPolicyId = policyToDelete.value.id;
    await conversationDistributionAPI.deletePolicy(deletedPolicyId);

    if (editingPolicyId.value === deletedPolicyId) {
      policyDialogRef.value?.close();
      resetEditor();
    }

    await fetchPolicies();
    closeDeletePolicy();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DELETED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERRORS.POLICIES_DELETE'));
  } finally {
    isDeleting.value = false;
  }
};

onMounted(() => {
  store.dispatch('teams/get');
  fetchPolicies();
});
</script>

<template>
  <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
    <div
      class="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
    >
      <div>
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.NEW')"
        icon="i-lucide-plus"
        md
        @click="openCreatePolicy"
      />
    </div>

    <div v-if="isFetching" class="grid min-h-48 place-content-center">
      <Spinner />
    </div>

    <div
      v-else-if="policies.length"
      class="flex flex-col gap-4 pt-4"
    >
      <DistributionPolicyCard
        v-for="policy in policies"
        :id="policy.id"
        :key="policy.id"
        :name="policy.name"
        :enabled="policy.enabled"
        :linked-channels-count="policy.linked_channels_count || 0"
        :linked-teams-count="policy.linked_teams_count || 0"
        :assignment-order="policy.config?.distribution?.assignment_order"
        :conversation-priority="
          policy.config?.distribution?.conversation_priority
        "
        @edit="openEditPolicy"
        @delete="openDeletePolicy"
      />
    </div>

    <div
      v-else
      class="grid min-h-48 place-content-center rounded-xl border border-dashed border-n-weak p-6 text-center text-body-main text-n-slate-11"
    >
      {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.EMPTY') }}
    </div>

    <Dialog
      ref="policyDialogRef"
      width="3xl"
      position="top"
      overflow-y-auto
      :title="dialogTitle"
      :confirm-button-label="
        t('IBSOFT_THEME.CONVERSATION_DISTRIBUTION.ACTIONS.SAVE')
      "
      :disable-confirm-button="isPolicyNameBlank"
      :is-loading="isSaving"
      @confirm="savePolicy"
      @close="resetEditor"
    >
      <div class="space-y-5">
        <div class="rounded-xl border border-n-weak px-4 py-3">
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.NAME') }}
            </span>
            <input
              v-model="policyName"
              type="text"
              class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
            />
          </label>

          <p
            v-if="selectedPolicyUsage"
            class="mb-0 mt-2 text-body-small text-n-slate-11"
          >
            {{ selectedPolicyUsage }}
          </p>
        </div>

        <DistributionPolicyForm
          v-model:enabled="enabled"
          v-model="config"
          :teams="teams"
          :is-loading="isSaving"
          :show-actions="false"
          @save="savePolicy"
        />
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DELETE_TITLE')"
      :description="t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DELETE_MESSAGE')"
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DELETE_CONFIRM')
      "
      :cancel-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.POLICIES.DELETE_CANCEL')
      "
      :is-loading="isDeleting"
      @confirm="confirmDeletePolicy"
      @close="policyToDelete = null"
    />
  </section>
</template>
