<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { picoSearch } from '@scmmishra/pico-search';

import Avatar from 'next/avatar/Avatar.vue';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import ChannelName from 'dashboard/routes/dashboard/settings/inbox/components/ChannelName.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  useMapGetter,
  useStore,
  useStoreGetters,
} from 'dashboard/composables/store';
import AutomationHandoffPolicyModal from './AutomationHandoffPolicyModal.vue';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const { isAdmin } = useAdmin();

const selectedInbox = ref({});
const searchQuery = ref('');
const showDeletePopup = ref(false);
const automationHandoffModalRef = ref(null);

const inboxes = useMapGetter('inboxes/getInboxes');
const teams = computed(() => store.getters['teams/getTeams'] || []);

const inboxesList = computed(() =>
  [...(inboxes.value || [])].sort((a, b) =>
    (a.name || '').localeCompare(b.name || '')
  )
);

const filteredInboxesList = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return inboxesList.value;
  return picoSearch(inboxesList.value, query, ['name', 'channel_type']);
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);
const channelsCountLabel = computed(() => {
  if (inboxesList.value.length === 1) {
    return t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.COUNT_ONE', {
      count: inboxesList.value.length,
    });
  }

  return t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.COUNT_MANY', {
    count: inboxesList.value.length,
  });
});

const deleteConfirmText = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_CONFIRM')
);

const deleteRejectText = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_CANCEL')
);

const confirmDeleteMessage = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_MESSAGE', {
    name: selectedInbox.value.name,
  })
);

const confirmPlaceHolderText = computed(() =>
  t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_PLACEHOLDER', {
    name: selectedInbox.value.name,
  })
);

const openDelete = inbox => {
  selectedInbox.value = inbox;
  showDeletePopup.value = true;
};

const openAutomationHandoff = inbox => {
  automationHandoffModalRef.value?.open(inbox);
};

const supportsMetaTemplates = inbox =>
  inbox.channel_type === 'Channel::Whatsapp' &&
  inbox.provider === 'whatsapp_cloud';

const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = async () => {
  try {
    await store.dispatch('inboxes/delete', selectedInbox.value.id);
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_SUCCESS'));
  } catch {
    useAlert(t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_ERROR'));
  } finally {
    closeDelete();
  }
};

onMounted(() => {
  store.dispatch('teams/get');
});
</script>

<template>
  <section class="grid min-w-0 gap-5">
    <BaseSettingsHeader
      v-model:search-query="searchQuery"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.TITLE')"
      :description="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DESCRIPTION')"
      :search-placeholder="
        t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.SEARCH_PLACEHOLDER')
      "
    >
      <template v-if="inboxesList.length" #count>
        <span class="text-body-main text-n-slate-11">
          {{ channelsCountLabel }}
        </span>
      </template>
      <template #actions>
        <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
          <Button
            :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.NEW')"
            size="sm"
          />
        </router-link>
      </template>
    </BaseSettingsHeader>

    <div v-if="uiFlags.isFetching" class="grid min-h-80 place-content-center">
      <Spinner />
    </div>

    <div
      v-else-if="!filteredInboxesList.length"
      class="grid min-h-80 place-content-center rounded-lg border border-dashed border-n-weak bg-n-alpha-1 p-8 text-center"
    >
      <p class="mb-0 text-body-main text-n-slate-11">
        {{
          searchQuery
            ? t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.NO_RESULTS')
            : t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.EMPTY')
        }}
      </p>
    </div>

    <div v-else class="grid gap-4 md:grid-cols-2 2xl:grid-cols-3">
      <article
        v-for="inbox in filteredInboxesList"
        :key="inbox.id"
        class="flex min-h-40 flex-col justify-between gap-5 rounded-lg border border-n-weak bg-n-solid-2 p-4 transition-colors hover:border-n-strong"
      >
        <div class="flex min-w-0 items-start gap-3">
          <div
            v-if="inbox.avatar_url"
            class="grid size-11 shrink-0 place-items-center rounded-lg border border-n-strong bg-n-alpha-3 shadow-sm ring ring-n-solid-1"
          >
            <Avatar
              :src="inbox.avatar_url"
              :name="inbox.name"
              :size="28"
              rounded-full
            />
          </div>
          <div
            v-else
            class="grid size-11 shrink-0 place-items-center rounded-lg border border-n-strong bg-n-alpha-3 shadow-sm ring ring-n-solid-1"
          >
            <ChannelIcon class="size-6 text-n-slate-10" :inbox="inbox" />
          </div>

          <div class="min-w-0">
            <h3 class="mb-1 line-clamp-2 text-heading-3 text-n-slate-12">
              {{ inbox.name }}
            </h3>
            <ChannelName
              :channel-type="inbox.channel_type"
              :medium="inbox.medium"
              :voice-enabled="inbox.voice_enabled"
              class="text-body-small text-n-slate-11"
            />
          </div>
        </div>

        <div
          class="flex items-center justify-end gap-2 border-t border-n-weak pt-3"
        >
          <router-link
            v-if="isAdmin && supportsMetaTemplates(inbox)"
            :to="{
              name: 'ibsoft_meta_templates',
              params: { inboxId: inbox.id },
            }"
          >
            <Button
              v-tooltip.top="t('IBSOFT_META_TEMPLATES.CARD_ACTION')"
              icon="i-lucide-layout-template"
              slate
              sm
              ghost
              :aria-label="t('IBSOFT_META_TEMPLATES.CARD_ACTION')"
            />
          </router-link>
          <Button
            v-if="isAdmin"
            :label="
              t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNEL_OPERATIONS.BUTTON')
            "
            icon="i-lucide-sliders-horizontal"
            slate
            sm
            @click="openAutomationHandoff(inbox)"
          />
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: inbox.id },
            }"
          >
            <Button
              v-if="isAdmin"
              :label="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.SETTINGS')"
              icon="i-lucide-settings"
              slate
              sm
            />
          </router-link>
          <Button
            v-if="isAdmin"
            v-tooltip.top="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE')"
            icon="i-lucide-trash"
            slate
            sm
            ghost
            class="hover:enabled:bg-n-ruby-2 hover:enabled:text-n-ruby-11"
            @click="openDelete(inbox)"
          />
        </div>
      </article>
    </div>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="t('IBSOFT_THEME.CHATHUB_SETTINGS.CHANNELS.DELETE_TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />

    <AutomationHandoffPolicyModal
      ref="automationHandoffModalRef"
      :teams="teams"
    />
  </section>
</template>
