<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';

import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import ChannelName from 'dashboard/routes/dashboard/settings/inbox/components/ChannelName.vue';
import { useAlert } from 'dashboard/composables';
import messageSignatureAPI from '../api';

const { t } = useI18n();
const store = useStore();

const isFetching = ref(false);
const isSaving = ref(false);
const searchQuery = ref('');
const enabled = ref(false);
const selectedInboxIds = ref([]);

const inboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const currentUser = computed(() => store.getters.getCurrentUser || {});
const sortedInboxes = computed(() =>
  [...inboxes.value].sort((left, right) =>
    (left.name || '').localeCompare(right.name || '')
  )
);
const filteredInboxes = computed(() => {
  const query = searchQuery.value.trim().toLocaleLowerCase();
  if (!query) return sortedInboxes.value;

  return sortedInboxes.value.filter(inbox =>
    [inbox.name, inbox.channel_type, inbox.medium]
      .filter(Boolean)
      .some(value => value.toLocaleLowerCase().includes(query))
  );
});
const previewAgentName = computed(
  () =>
    currentUser.value.name ||
    t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.PREVIEW.AGENT')
);
const selectedCountLabel = computed(() => {
  const count = selectedInboxIds.value.length;
  const key =
    count === 1
      ? 'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.COUNT_ONE'
      : 'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.COUNT_MANY';

  return t(key, { count });
});

const isInboxSelected = inboxId => selectedInboxIds.value.includes(inboxId);

const toggleInbox = inboxId => {
  selectedInboxIds.value = isInboxSelected(inboxId)
    ? selectedInboxIds.value.filter(id => id !== inboxId)
    : [...selectedInboxIds.value, inboxId].sort((left, right) => left - right);
};

const fetchSetting = async () => {
  isFetching.value = true;
  try {
    const [{ data }] = await Promise.all([
      messageSignatureAPI.getSetting(),
      store.dispatch('inboxes/get'),
    ]);
    enabled.value = Boolean(data.enabled);
    selectedInboxIds.value = [...(data.inbox_ids || [])];
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const saveSetting = async () => {
  if (enabled.value && selectedInboxIds.value.length === 0) {
    useAlert(
      t(
        'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ERRORS.CHANNEL_REQUIRED'
      )
    );
    return;
  }

  isSaving.value = true;
  try {
    const { data } = await messageSignatureAPI.updateSetting({
      enabled: enabled.value,
      inbox_ids: selectedInboxIds.value,
    });
    enabled.value = Boolean(data.enabled);
    selectedInboxIds.value = [...(data.inbox_ids || [])];
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.SAVED'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(fetchSetting);
</script>

<template>
  <section class="grid min-w-0 gap-5">
    <BaseSettingsHeader
      v-model:search-query="searchQuery"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.TITLE')"
      :description="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.DESCRIPTION')
      "
      :search-placeholder="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.SEARCH_PLACEHOLDER')
      "
    />

    <div v-if="isFetching" class="grid min-h-80 place-content-center">
      <Spinner />
    </div>

    <template v-else>
      <section class="rounded-lg border border-n-weak bg-n-alpha-1 p-4">
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <h2 class="mb-1 text-heading-2 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ENABLE.TITLE'
                )
              }}
            </h2>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.ENABLE.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <ToggleSwitch v-model="enabled" class="shrink-0" />
        </div>
      </section>

      <section
        class="grid gap-4 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <header class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h2 class="mb-1 text-heading-2 text-n-slate-12">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.TITLE'
                )
              }}
            </h2>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{
                t(
                  'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.DESCRIPTION'
                )
              }}
            </p>
          </div>
          <span class="text-body-small text-n-slate-11">
            {{ selectedCountLabel }}
          </span>
        </header>

        <div
          v-if="!filteredInboxes.length"
          class="grid min-h-40 place-content-center rounded-lg border border-dashed border-n-weak bg-n-solid-1 p-6 text-center"
        >
          <p class="mb-0 text-body-main text-n-slate-11">
            {{
              searchQuery
                ? t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.NO_RESULTS'
                  )
                : t(
                    'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.CHANNELS.EMPTY'
                  )
            }}
          </p>
        </div>

        <div v-else class="grid gap-2 md:grid-cols-2">
          <label
            v-for="inbox in filteredInboxes"
            :key="inbox.id"
            class="flex min-w-0 cursor-pointer items-center gap-3 rounded-lg border border-n-weak bg-n-solid-1 p-3 text-left transition-colors hover:border-n-strong hover:bg-n-alpha-2"
          >
            <Checkbox
              :model-value="isInboxSelected(inbox.id)"
              class="shrink-0"
              @change="toggleInbox(inbox.id)"
            />
            <span
              class="grid size-9 shrink-0 place-items-center rounded-lg bg-n-alpha-2"
            >
              <ChannelIcon class="size-5 text-n-slate-11" :inbox="inbox" />
            </span>
            <span class="min-w-0 flex-1">
              <strong class="block truncate text-label-medium text-n-slate-12">
                {{ inbox.name }}
              </strong>
              <ChannelName
                :channel-type="inbox.channel_type"
                :medium="inbox.medium"
                :voice-enabled="inbox.voice_enabled"
                class="block truncate text-body-small text-n-slate-11"
              />
            </span>
          </label>
        </div>
      </section>

      <section
        class="grid gap-3 rounded-lg border border-n-weak bg-n-alpha-1 p-4"
      >
        <div>
          <h2 class="mb-1 text-heading-2 text-n-slate-12">
            {{
              t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.PREVIEW.TITLE')
            }}
          </h2>
          <p class="mb-0 text-body-main text-n-slate-11">
            {{
              t(
                'IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.PREVIEW.DESCRIPTION'
              )
            }}
          </p>
        </div>
        <div
          class="max-w-xl rounded-lg border border-n-weak bg-n-solid-1 px-4 py-3 text-body-main text-n-slate-12"
        >
          <strong class="mb-2 block">{{ previewAgentName }}</strong>
          <p class="mb-0 whitespace-pre-wrap">
            {{
              t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.PREVIEW.BODY')
            }}
          </p>
        </div>
      </section>

      <div class="flex justify-end">
        <Button
          :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.MESSAGE_SIGNATURE.SAVE')"
          icon="i-lucide-save"
          :is-loading="isSaving"
          @click="saveSetting"
        />
      </div>
    </template>
  </section>
</template>
