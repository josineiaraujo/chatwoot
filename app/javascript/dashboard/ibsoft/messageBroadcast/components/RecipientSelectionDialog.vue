<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  purpose: {
    type: String,
    default: 'recipients',
    validator: value => ['recipients', 'group', 'group-edit'].includes(value),
  },
  groupName: {
    type: String,
    default: '',
  },
  selectionCount: {
    type: Number,
    default: 0,
  },
  currentPageCount: {
    type: Number,
    default: 0,
  },
  totalCount: {
    type: Number,
    default: 0,
  },
  selectionScope: {
    type: String,
    default: 'none',
  },
  allowSelectAll: {
    type: Boolean,
    default: true,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'close',
  'confirm',
  'select-page',
  'select-all',
  'clear-selection',
  'update:groupName',
]);

const { t } = useI18n();
const dialogRef = ref(null);

const isGroupPurpose = computed(() => props.purpose === 'group');
const isGroupEditPurpose = computed(() => props.purpose === 'group-edit');
const title = computed(() => {
  if (isGroupPurpose.value) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_TITLE');
  }
  if (isGroupEditPurpose.value) {
    return t(
      'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_EDIT_TITLE'
    );
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.RECIPIENTS_TITLE');
});
const confirmLabel = computed(() => {
  if (isGroupPurpose.value) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.CREATE_GROUP', {
      count: props.selectionCount,
    });
  }
  if (isGroupEditPurpose.value) {
    return t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.ADD_TO_GROUP', {
      count: props.selectionCount,
    });
  }

  return t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.ADD_RECIPIENTS', {
    count: props.selectionCount,
  });
});
const disableConfirm = computed(
  () =>
    props.selectionCount === 0 ||
    (isGroupPurpose.value && props.groupName.trim().length === 0)
);

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="title"
    width="3xl"
    position="top"
    overflow-y-auto
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="emit('close')"
  >
    <div
      class="ibsoft-recipient-selection-dialog flex max-h-[calc(100vh-14rem)] min-h-0 flex-col gap-4"
    >
      <label
        v-if="isGroupPurpose"
        class="grid shrink-0 gap-1 text-sm text-n-slate-11"
      >
        {{
          t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_NAME_LABEL')
        }}
        <input
          :value="groupName"
          class="!mb-0 min-h-10 w-full rounded-lg border-0 bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          :placeholder="
            t(
              'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.GROUP_NAME_PLACEHOLDER'
            )
          "
          @input="emit('update:groupName', $event.target.value)"
        />
      </label>

      <div class="min-h-0 overflow-y-auto pr-1">
        <slot name="filters" />

        <div
          v-if="totalCount > 0 && allowSelectAll"
          class="my-4 flex flex-wrap items-center gap-2 rounded-lg bg-n-alpha-1 p-2 outline outline-1 outline-n-weak"
          data-testid="recipient-selection-toolbar"
        >
          <Button
            variant="secondary"
            icon="i-lucide-list-checks"
            :class="
              selectionScope === 'page'
                ? 'outline outline-1 outline-n-brand'
                : ''
            "
            :label="
              t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.SELECT_PAGE', {
                count: currentPageCount,
              })
            "
            :disabled="currentPageCount === 0"
            @click="emit('select-page')"
          />
          <Button
            variant="secondary"
            icon="i-lucide-list-plus"
            :class="
              selectionScope === 'all'
                ? 'outline outline-1 outline-n-brand'
                : ''
            "
            :label="
              t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.SELECT_ALL', {
                count: totalCount,
              })
            "
            @click="emit('select-all')"
          />
          <Button
            v-if="selectionCount > 0"
            variant="ghost"
            icon="i-lucide-x"
            :label="
              t(
                'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.CLEAR_SELECTION'
              )
            "
            @click="emit('clear-selection')"
          />
        </div>

        <slot name="results" />
      </div>
    </div>

    <template #footer>
      <div class="flex w-full flex-wrap items-center justify-between gap-3">
        <div
          class="inline-flex min-h-9 items-center gap-2 rounded-lg bg-n-alpha-1 px-3 text-sm font-medium text-n-slate-12 outline outline-1 outline-n-weak"
          data-testid="recipient-selection-count"
        >
          <span class="i-lucide-users-round size-4 text-n-brand" />
          {{
            t(
              'IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.SELECTED_COUNT',
              { count: selectionCount }
            )
          }}
        </div>
        <div class="flex items-center gap-2">
          <Button
            variant="faded"
            color="slate"
            :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.SELECTION_DIALOG.CANCEL')"
            @click="close"
          />
          <Button
            :label="confirmLabel"
            :disabled="disableConfirm || isLoading"
            :is-loading="isLoading"
            @click="emit('confirm')"
          />
        </div>
      </div>
    </template>
  </Dialog>
</template>

<style scoped>
:global(dialog:has(.ibsoft-recipient-selection-dialog)) {
  max-width: min(72rem, calc(100vw - 2rem));
}
</style>
