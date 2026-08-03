<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import RecipientTable from './RecipientTable.vue';

const props = defineProps({
  groupName: {
    type: String,
    default: '',
  },
  members: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  isSaving: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'add',
  'close',
  'remove',
  'save',
  'update',
  'update:groupName',
]);

const { t } = useI18n();
const dialogRef = ref(null);
const disableSave = computed(
  () => props.isLoading || props.isSaving || !props.groupName.trim()
);

const open = () => dialogRef.value?.open();
const close = () => dialogRef.value?.close();

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="3xl"
    position="top"
    overflow-y-auto
    :title="t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.TITLE')"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="emit('close')"
  >
    <div v-if="isLoading" class="flex min-h-64 items-center justify-center">
      <Spinner />
    </div>

    <div
      v-else
      class="ibsoft-group-editor-dialog grid max-h-[65vh] min-h-0 gap-4 overflow-y-auto pr-1"
    >
      <label class="grid gap-1 text-sm text-n-slate-11">
        {{ t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.NAME') }}
        <input
          :value="groupName"
          class="!mb-0 min-h-10 w-full rounded-lg border-0 bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          :placeholder="
            t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.NAME_PLACEHOLDER')
          "
          @input="emit('update:groupName', $event.target.value)"
        />
      </label>

      <div class="flex justify-end">
        <Button
          icon="i-lucide-user-plus"
          :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.ADD_MEMBERS')"
          @click="emit('add')"
        />
      </div>

      <RecipientTable
        :recipients="members"
        :show-continue="false"
        :empty-message="t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.EMPTY')"
        @remove="emit('remove', $event)"
        @update="emit('update', $event)"
      />
    </div>

    <template #footer>
      <div class="flex w-full justify-end gap-2">
        <Button
          variant="faded"
          color="slate"
          :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.CANCEL')"
          :disabled="isSaving"
          @click="close"
        />
        <Button
          icon="i-lucide-save"
          :label="t('IBSOFT_THEME.MESSAGE_BROADCAST.GROUPS.EDITOR.SAVE')"
          :disabled="disableSave"
          :is-loading="isSaving"
          @click="emit('save')"
        />
      </div>
    </template>
  </Dialog>
</template>

<style scoped>
:global(dialog:has(.ibsoft-group-editor-dialog)) {
  max-width: min(56rem, calc(100vw - 2rem));
}
</style>
