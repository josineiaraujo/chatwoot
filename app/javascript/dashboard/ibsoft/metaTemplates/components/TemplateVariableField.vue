<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import {
  extractVariables,
  insertVariableAtSelection,
  isValidNamedVariable,
  nextPositionalVariable,
} from '../templateModel';

const props = defineProps({
  fieldId: { type: String, required: true },
  label: { type: String, required: true },
  parameterFormat: {
    type: String,
    required: true,
    validator: value => ['named', 'positional'].includes(value),
  },
  hasExampleError: { type: Boolean, default: false },
});

const text = defineModel('text', { type: String, required: true });
const examples = defineModel('examples', { type: Object, required: true });
const { t } = useI18n();

const variableName = ref('');
const selection = ref(null);
const attemptedNamedInsert = ref(false);
const fieldRoot = ref(null);

const variables = computed(() => [
  ...new Set(extractVariables(text.value, props.parameterFormat)),
]);
const trimmedVariableName = computed(() => variableName.value.trim());
const namedVariableIsValid = computed(() =>
  isValidNamedVariable(trimmedVariableName.value)
);
const namedVariableHasError = computed(
  () => attemptedNamedInsert.value && !namedVariableIsValid.value
);

const fieldElement = () =>
  fieldRoot.value?.querySelector(`#${props.fieldId}`) ||
  document.getElementById(props.fieldId);

const captureSelection = () => {
  const element = fieldElement();
  selection.value = element
    ? {
        start: element.selectionStart,
        end: element.selectionEnd,
      }
    : null;
};

const rememberFieldSelection = event => {
  if (event.target?.id !== props.fieldId) return;
  selection.value = {
    start: event.target.selectionStart,
    end: event.target.selectionEnd,
  };
};

const restoreCursor = async cursor => {
  await nextTick();
  const element = fieldElement();
  if (!element) return;

  element.focus();
  element.setSelectionRange(cursor, cursor);
};

const insertVariable = variable => {
  const element = fieldElement();
  const currentSelection = selection.value || {
    start: element?.selectionStart,
    end: element?.selectionEnd,
  };
  const result = insertVariableAtSelection({
    text: text.value,
    variable,
    selectionStart: currentSelection.start,
    selectionEnd: currentSelection.end,
  });

  text.value = result.text;
  selection.value = null;
  restoreCursor(result.cursor);
};

const insertPositionalVariable = () => {
  insertVariable(nextPositionalVariable(text.value));
};

const insertNamedVariable = hide => {
  attemptedNamedInsert.value = true;
  if (!namedVariableIsValid.value) return;

  insertVariable(trimmedVariableName.value);
  variableName.value = '';
  attemptedNamedInsert.value = false;
  hide();
};

const resetNamedVariable = () => {
  variableName.value = '';
  attemptedNamedInsert.value = false;
};
</script>

<template>
  <div
    ref="fieldRoot"
    class="grid gap-2"
    @focusout="rememberFieldSelection"
    @keyup="rememberFieldSelection"
    @mouseup="rememberFieldSelection"
    @select="rememberFieldSelection"
  >
    <div class="flex min-w-0 flex-wrap items-center justify-between gap-2">
      <label :for="fieldId" class="text-heading-3 text-n-slate-12">
        {{ label }}
      </label>

      <Popover
        v-if="parameterFormat === 'named'"
        align="end"
        disable-mobile-view
        @hide="resetNamedVariable"
      >
        <Button
          type="button"
          icon="i-lucide-braces"
          color="slate"
          variant="outline"
          size="sm"
          :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.ADD_VARIABLE')"
          @mousedown="captureSelection"
        />

        <template #content="{ hide }">
          <div class="grid w-72 gap-3 p-4">
            <Input
              v-model="variableName"
              autofocus
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.VARIABLE_NAME')"
              :placeholder="
                t(
                  'IBSOFT_META_TEMPLATES.EDITOR.CONTENT.VARIABLE_NAME_PLACEHOLDER'
                )
              "
              :message="
                namedVariableHasError
                  ? t(
                      'IBSOFT_META_TEMPLATES.EDITOR.CONTENT.VARIABLE_NAME_ERROR'
                    )
                  : ''
              "
              :message-type="namedVariableHasError ? 'error' : 'info'"
              @enter="insertNamedVariable(hide)"
            />
            <Button
              type="button"
              icon="i-lucide-plus"
              :disabled="!namedVariableIsValid"
              :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.INSERT_VARIABLE')"
              @click="insertNamedVariable(hide)"
            />
          </div>
        </template>
      </Popover>

      <Button
        v-else
        type="button"
        icon="i-lucide-braces"
        color="slate"
        variant="outline"
        size="sm"
        :label="t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.ADD_VARIABLE')"
        @mousedown="captureSelection"
        @click="insertPositionalVariable"
      />
    </div>

    <slot />

    <div
      v-if="variables.length"
      class="grid gap-3 sm:grid-cols-2"
      :data-testid="`${fieldId}-examples`"
    >
      <Input
        v-for="variable in variables"
        :key="variable"
        v-model="examples[variable]"
        :label="
          t('IBSOFT_META_TEMPLATES.EDITOR.CONTENT.EXAMPLE', {
            variable: `{{${variable}}}`,
          })
        "
        :message="
          hasExampleError
            ? t('IBSOFT_META_TEMPLATES.EDITOR.ERRORS.CONTENT')
            : ''
        "
        :message-type="hasExampleError ? 'error' : 'info'"
      />
    </div>
  </div>
</template>
