<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import afterHoursAPI from '../api';

const { t } = useI18n();

const policies = ref([]);
const isFetching = ref(false);
const isSaving = ref(false);
const isDeleting = ref(false);
const editingId = ref(null);
const deletingPolicy = ref(null);
const editorRef = ref(null);
const deleteDialogRef = ref(null);
const form = ref({});

const emptyForm = () => ({
  name: '',
  enabled: false,
  exit_command: 'sair',
  regular_message: '',
  holiday_message: '',
  exit_confirmation_message: '',
});

const isEditing = computed(() => editingId.value !== null);
const dialogTitle = computed(() =>
  t(
    isEditing.value
      ? 'IBSOFT_AFTER_HOURS.EDITOR.EDIT_TITLE'
      : 'IBSOFT_AFTER_HOURS.EDITOR.CREATE_TITLE'
  )
);
const invalidForm = computed(
  () =>
    !form.value.name?.trim() ||
    !form.value.exit_command?.trim() ||
    (form.value.enabled &&
      (!form.value.regular_message?.trim() ||
        !form.value.holiday_message?.trim() ||
        !form.value.exit_confirmation_message?.trim()))
);

const fetchPolicies = async () => {
  isFetching.value = true;
  try {
    const { data } = await afterHoursAPI.getPolicies();
    policies.value = data.policies || [];
  } catch {
    useAlert(t('IBSOFT_AFTER_HOURS.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const openEditor = async policy => {
  editingId.value = policy?.id ?? null;
  form.value = policy ? { ...policy } : emptyForm();
  await nextTick();
  editorRef.value?.open();
};

const closeEditor = () => {
  editorRef.value?.close();
};

const resetEditor = () => {
  editingId.value = null;
  form.value = emptyForm();
};

const savePolicy = async () => {
  isSaving.value = true;
  try {
    if (isEditing.value) {
      await afterHoursAPI.updatePolicy(editingId.value, form.value);
    } else {
      await afterHoursAPI.createPolicy(form.value);
    }
    await fetchPolicies();
    closeEditor();
    useAlert(t('IBSOFT_AFTER_HOURS.SAVED'));
  } catch {
    useAlert(t('IBSOFT_AFTER_HOURS.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const openDeleteDialog = async policy => {
  deletingPolicy.value = policy;
  await nextTick();
  deleteDialogRef.value?.open();
};

const deletePolicy = async () => {
  if (!deletingPolicy.value) return;

  isDeleting.value = true;
  try {
    await afterHoursAPI.deletePolicy(deletingPolicy.value.id);
    await fetchPolicies();
    deleteDialogRef.value?.close();
    deletingPolicy.value = null;
    useAlert(t('IBSOFT_AFTER_HOURS.DELETED'));
  } catch {
    useAlert(t('IBSOFT_AFTER_HOURS.ERRORS.DELETE'));
  } finally {
    isDeleting.value = false;
  }
};

onMounted(fetchPolicies);
</script>

<template>
  <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
    <div
      class="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
    >
      <div>
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_AFTER_HOURS.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ t('IBSOFT_AFTER_HOURS.DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="t('IBSOFT_AFTER_HOURS.NEW')"
        icon="i-lucide-plus"
        @click="openEditor()"
      />
    </div>

    <div v-if="isFetching" class="grid min-h-48 place-content-center">
      <Spinner />
    </div>

    <div v-else-if="policies.length" class="grid gap-3">
      <article
        v-for="policy in policies"
        :key="policy.id"
        class="flex flex-col gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-4 md:flex-row md:items-center md:justify-between"
      >
        <div class="min-w-0">
          <div class="mb-1 flex flex-wrap items-center gap-2">
            <h3 class="mb-0 truncate text-heading-3 text-n-slate-12">
              {{ policy.name }}
            </h3>
            <span
              class="rounded-md px-2 py-0.5 text-label-mini"
              :class="
                policy.enabled
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
            >
              {{
                t(
                  policy.enabled
                    ? 'IBSOFT_AFTER_HOURS.STATUS.ENABLED'
                    : 'IBSOFT_AFTER_HOURS.STATUS.DISABLED'
                )
              }}
            </span>
          </div>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t('IBSOFT_AFTER_HOURS.CARD.DETAILS', {
                command: policy.exit_command,
                count: policy.linked_distribution_policies_count || 0,
              })
            }}
          </p>
        </div>

        <div class="flex shrink-0 items-center gap-1">
          <Button
            icon="i-lucide-pencil"
            variant="ghost"
            color="slate"
            :label="t('IBSOFT_AFTER_HOURS.ACTIONS.EDIT')"
            @click="openEditor(policy)"
          />
          <Button
            icon="i-lucide-trash-2"
            variant="ghost"
            color="ruby"
            :label="t('IBSOFT_AFTER_HOURS.ACTIONS.DELETE')"
            @click="openDeleteDialog(policy)"
          />
        </div>
      </article>
    </div>

    <div
      v-else
      class="grid min-h-48 place-content-center rounded-lg border border-dashed border-n-weak p-6 text-center text-body-main text-n-slate-11"
    >
      {{ t('IBSOFT_AFTER_HOURS.EMPTY') }}
    </div>

    <Dialog
      ref="editorRef"
      width="2xl"
      position="top"
      overflow-y-auto
      :title="dialogTitle"
      :confirm-button-label="t('IBSOFT_AFTER_HOURS.ACTIONS.SAVE')"
      :disable-confirm-button="invalidForm"
      :is-loading="isSaving"
      @confirm="savePolicy"
      @close="resetEditor"
    >
      <div class="grid gap-4">
        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.NAME') }}
          </span>
          <input
            v-model="form.name"
            type="text"
            class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
        </label>

        <div
          class="flex items-center justify-between gap-4 rounded-lg border border-n-weak p-3"
        >
          <div>
            <p class="mb-1 text-label-medium text-n-slate-12">
              {{ t('IBSOFT_AFTER_HOURS.FIELDS.ENABLED') }}
            </p>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{ t('IBSOFT_AFTER_HOURS.FIELDS.ENABLED_HELP') }}
            </p>
          </div>
          <ToggleSwitch v-model="form.enabled" class="shrink-0" />
        </div>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.EXIT_COMMAND') }}
          </span>
          <input
            v-model="form.exit_command"
            type="text"
            maxlength="50"
            class="min-h-10 rounded-lg border border-n-weak bg-n-solid-1 px-3 text-sm text-n-slate-12"
          />
          <span class="text-body-mini text-n-slate-10">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.EXIT_COMMAND_HELP') }}
          </span>
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.REGULAR_MESSAGE') }}
          </span>
          <textarea
            v-model="form.regular_message"
            rows="4"
            class="resize-y rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
          />
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.HOLIDAY_MESSAGE') }}
          </span>
          <textarea
            v-model="form.holiday_message"
            rows="4"
            class="resize-y rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
          />
        </label>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_AFTER_HOURS.FIELDS.CONFIRMATION_MESSAGE') }}
          </span>
          <textarea
            v-model="form.exit_confirmation_message"
            rows="3"
            class="resize-y rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
          />
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('IBSOFT_AFTER_HOURS.DELETE.TITLE')"
      :description="t('IBSOFT_AFTER_HOURS.DELETE.DESCRIPTION')"
      :confirm-button-label="t('IBSOFT_AFTER_HOURS.ACTIONS.DELETE')"
      :is-loading="isDeleting"
      @confirm="deletePolicy"
      @close="deletingPolicy = null"
    />
  </section>
</template>
