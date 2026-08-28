<script setup>
import { computed, nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import erpAPI from '../api';
import {
  ERP_AUTH_FIELDS,
  buildCredentialPayload,
  defaultAuthTypeForProvider,
} from '../providerConfig';

const { t } = useI18n();

const providers = ref([]);
const connections = ref([]);
const isFetching = ref(false);
const isSaving = ref(false);
const isDeleting = ref(false);
const isCreating = ref(false);
const testingConnectionId = ref(null);
const editingConnectionId = ref(null);
const connectionToDelete = ref(null);
const editorDialogRef = ref(null);
const deleteDialogRef = ref(null);

const form = reactive({
  name: '',
  provider: '',
  auth_type: '',
  base_url: '',
  active: false,
  credentials: {},
});

const selectedProvider = computed(() =>
  providers.value.find(provider => provider.key === form.provider)
);

const selectedAuthTypes = computed(
  () => selectedProvider.value?.auth_types || []
);
const credentialFields = computed(() => ERP_AUTH_FIELDS[form.auth_type] || []);
const editingConnection = computed(() =>
  connections.value.find(
    connection => connection.id === editingConnectionId.value
  )
);
const dialogTitle = computed(() =>
  isCreating.value
    ? t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREATE_TITLE')
    : t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.EDIT_TITLE')
);
const isFormInvalid = computed(
  () =>
    !form.name.trim() ||
    !form.provider ||
    !form.auth_type ||
    !form.base_url.trim()
);

const providerOptions = computed(() =>
  providers.value.map(provider => ({
    value: provider.key,
    label: provider.label,
  }))
);

const authTypeOptions = computed(() =>
  selectedAuthTypes.value.map(authType => ({
    value: authType,
    label: t(
      `IBSOFT_THEME.CHATHUB_SETTINGS.ERP.AUTH_TYPES.${authType.toUpperCase()}`
    ),
  }))
);

const resetForm = () => {
  const firstProvider = providers.value[0];
  form.name = '';
  form.provider = firstProvider?.key || '';
  form.auth_type = defaultAuthTypeForProvider(firstProvider);
  form.base_url = '';
  form.active = connections.value.length === 0;
  form.credentials = {};
  editingConnectionId.value = null;
  isCreating.value = false;
};

const applyConnectionToForm = connection => {
  form.name = connection.name;
  form.provider = connection.provider;
  form.auth_type = connection.auth_type;
  form.base_url = connection.base_url;
  form.active = connection.active;
  form.credentials = {};
  editingConnectionId.value = connection.id;
  isCreating.value = false;
};

const fetchConnections = async () => {
  isFetching.value = true;
  try {
    const { data } = await erpAPI.getConnections();
    providers.value = data.providers || [];
    connections.value = data.connections || [];
    if (!form.provider) resetForm();
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const openEditor = async () => {
  await nextTick();
  editorDialogRef.value?.open();
};

const openCreate = () => {
  resetForm();
  isCreating.value = true;
  openEditor();
};

const openEdit = connection => {
  applyConnectionToForm(connection);
  openEditor();
};

const openDelete = connection => {
  connectionToDelete.value = connection;
  deleteDialogRef.value?.open();
};

const closeDelete = () => {
  connectionToDelete.value = null;
  deleteDialogRef.value?.close();
};

const saveConnection = async () => {
  isSaving.value = true;
  try {
    const payload = {
      name: form.name,
      provider: form.provider,
      auth_type: form.auth_type,
      base_url: form.base_url,
      active: form.active,
      credentials: buildCredentialPayload(form.auth_type, form.credentials),
      settings: {},
    };

    if (isCreating.value) {
      await erpAPI.createConnection(payload);
    } else {
      await erpAPI.updateConnection(editingConnectionId.value, payload);
    }

    await fetchConnections();
    editorDialogRef.value?.close();
    resetForm();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.SAVED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const activateConnection = async connection => {
  isSaving.value = true;
  try {
    await erpAPI.updateConnection(connection.id, { active: true });
    await fetchConnections();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVATED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const testConnection = async connection => {
  testingConnectionId.value = connection.id;
  try {
    const { data } = await erpAPI.testConnection(connection.id);
    const updatedConnection = data.connection;
    connections.value = connections.value.map(item =>
      item.id === updatedConnection.id ? updatedConnection : item
    );
    useAlert(
      t(
        data.test?.success
          ? 'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.SUCCESS'
          : 'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.FAILURE'
      )
    );
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.FAILURE'));
  } finally {
    testingConnectionId.value = null;
  }
};

const deleteConnection = async () => {
  if (!connectionToDelete.value) return;

  isDeleting.value = true;
  try {
    await erpAPI.deleteConnection(connectionToDelete.value.id);
    await fetchConnections();
    closeDelete();
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DELETED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ERRORS.DELETE'));
  } finally {
    isDeleting.value = false;
  }
};

watch(
  () => form.provider,
  providerKey => {
    const provider = providers.value.find(item => item.key === providerKey);
    if (!provider?.auth_types?.includes(form.auth_type)) {
      form.auth_type = defaultAuthTypeForProvider(provider);
    }
    form.credentials = {};
  }
);

watch(
  () => form.auth_type,
  () => {
    form.credentials = {};
  }
);

onMounted(fetchConnections);
</script>

<template>
  <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
    <div
      class="mb-4 flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
    >
      <div>
        <h2 class="mb-1 text-heading-2 text-n-slate-12">
          {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TITLE') }}
        </h2>
        <p class="mb-0 text-body-small text-n-slate-11">
          {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.NEW')"
        icon="i-lucide-plus"
        md
        @click="openCreate"
      />
    </div>

    <div v-if="isFetching" class="grid min-h-48 place-content-center">
      <Spinner />
    </div>

    <div v-else-if="connections.length" class="grid gap-3">
      <article
        v-for="connection in connections"
        :key="connection.id"
        class="rounded-xl border border-n-weak bg-n-alpha-1 p-4"
      >
        <div
          class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between"
        >
          <div class="min-w-0">
            <div class="mb-2 flex flex-wrap items-center gap-2">
              <span
                class="rounded-md bg-n-alpha-2 px-2 py-1 text-label-small text-n-slate-11"
              >
                {{ connection.provider_label }}
              </span>
              <span
                class="rounded-md px-2 py-1 text-label-small"
                :class="
                  connection.active
                    ? 'bg-n-brand/10 text-n-brand'
                    : 'bg-n-alpha-2 text-n-slate-11'
                "
              >
                {{
                  connection.active
                    ? t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVE_BADGE')
                    : t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.INACTIVE_BADGE')
                }}
              </span>
            </div>
            <h3 class="mb-1 truncate text-heading-3 text-n-slate-12">
              {{ connection.name }}
            </h3>
            <p class="mb-2 break-all text-body-small text-n-slate-11">
              {{ connection.base_url }}
            </p>
            <div
              class="flex flex-wrap divide-x divide-n-weak text-label-small text-n-slate-11"
            >
              <span class="pe-2">
                {{
                  t(
                    `IBSOFT_THEME.CHATHUB_SETTINGS.ERP.AUTH_TYPES.${connection.auth_type.toUpperCase()}`
                  )
                }}
              </span>
              <span class="ps-2">
                {{
                  connection.credentials_configured
                    ? t(
                        'IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREDENTIALS_CONFIGURED'
                      )
                    : t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREDENTIALS_MISSING')
                }}
              </span>
              <span v-if="connection.last_test_status" class="ps-2">
                {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.LAST_STATUS') }}:
                {{
                  t(
                    `IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.STATUS.${connection.last_test_status.toUpperCase()}`
                  )
                }}
              </span>
            </div>
          </div>

          <div class="flex shrink-0 flex-wrap gap-2">
            <Button
              :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.TEST.BUTTON')"
              icon="i-lucide-refresh-cw"
              sm
              slate
              :is-loading="testingConnectionId === connection.id"
              @click="testConnection(connection)"
            />
            <Button
              v-if="!connection.active"
              :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVATE')"
              sm
              slate
              @click="activateConnection(connection)"
            />
            <Button
              :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.EDIT')"
              icon="i-lucide-pencil"
              sm
              slate
              @click="openEdit(connection)"
            />
            <Button
              :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DELETE')"
              icon="i-lucide-trash-2"
              sm
              color="ruby"
              variant="faded"
              @click="openDelete(connection)"
            />
          </div>
        </div>
      </article>
    </div>

    <div
      v-else
      class="grid min-h-48 place-content-center rounded-xl border border-dashed border-n-weak p-6 text-center text-body-main text-n-slate-11"
    >
      {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.EMPTY') }}
    </div>

    <Dialog
      ref="editorDialogRef"
      width="2xl"
      position="top"
      overflow-y-auto
      :title="dialogTitle"
      :confirm-button-label="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.SAVE')"
      :disable-confirm-button="isFormInvalid"
      :is-loading="isSaving"
      @confirm="saveConnection"
      @close="resetForm"
    >
      <div class="grid gap-4">
        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.NAME') }}
          </span>
          <input
            v-model="form.name"
            type="text"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            :placeholder="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.NAME_PLACEHOLDER')
            "
          />
        </label>

        <div class="grid gap-4 md:grid-cols-2">
          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.PROVIDER') }}
            </span>
            <IbsoftSelect v-model="form.provider">
              <option
                v-for="provider in providerOptions"
                :key="provider.value"
                :value="provider.value"
              >
                {{ provider.label }}
              </option>
            </IbsoftSelect>
          </label>

          <label class="grid gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.AUTH_TYPE') }}
            </span>
            <IbsoftSelect v-model="form.auth_type">
              <option
                v-for="authType in authTypeOptions"
                :key="authType.value"
                :value="authType.value"
              >
                {{ authType.label }}
              </option>
            </IbsoftSelect>
          </label>
        </div>

        <label class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.BASE_URL') }}
          </span>
          <input
            v-model="form.base_url"
            type="url"
            class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
            :placeholder="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.BASE_URL_PLACEHOLDER')
            "
          />
        </label>

        <section class="rounded-xl border border-n-weak bg-n-alpha-1 p-4">
          <h3 class="mb-1 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREDENTIALS_TITLE') }}
          </h3>
          <p class="mb-4 text-body-small text-n-slate-11">
            {{
              editingConnection?.credentials_configured
                ? t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.PRESERVE_SECRET_HINT')
                : t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREDENTIALS_DESCRIPTION')
            }}
          </p>

          <div class="grid gap-4 md:grid-cols-2">
            <label
              v-for="field in credentialFields"
              :key="field"
              class="grid gap-1"
            >
              <span class="text-label-small text-n-slate-11">
                {{
                  t(
                    `IBSOFT_THEME.CHATHUB_SETTINGS.ERP.CREDENTIAL_FIELDS.${field.toUpperCase()}`
                  )
                }}
              </span>
              <input
                v-model="form.credentials[field]"
                :type="
                  field === 'password' || field === 'token'
                    ? 'password'
                    : 'text'
                "
                autocomplete="new-password"
                class="w-full rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm text-n-slate-12"
              />
            </label>
          </div>
        </section>

        <label
          class="flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-alpha-1 p-4"
        >
          <span>
            <span class="block text-sm font-medium text-n-slate-12">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVE_TITLE') }}
            </span>
            <span class="block text-body-small text-n-slate-11">
              {{ t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.ACTIVE_DESCRIPTION') }}
            </span>
          </span>
          <ToggleSwitch v-model="form.active" class="shrink-0" />
        </label>
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DELETE_TITLE')"
      :confirm-button-label="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DELETE_CONFIRM')
      "
      :is-loading="isDeleting"
      @confirm="deleteConnection"
      @close="closeDelete"
    >
      <p class="mb-0 text-body-main text-n-slate-11">
        {{
          t('IBSOFT_THEME.CHATHUB_SETTINGS.ERP.DELETE_MESSAGE', {
            name: connectionToDelete?.name,
          })
        }}
      </p>
    </Dialog>
  </section>
</template>
