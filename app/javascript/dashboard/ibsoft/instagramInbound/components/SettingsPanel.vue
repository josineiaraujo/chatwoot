<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import { useAlert } from 'dashboard/composables';
import instagramInboundAPI from '../api';

const props = defineProps({
  inboxId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const isFetching = ref(false);
const isSaving = ref(false);
const hasLoadError = ref(false);
const form = reactive({
  create_from_story_interactions: true,
  create_from_shared_reels_and_stories: true,
  create_from_shared_posts: true,
});

const options = computed(() => [
  {
    key: 'create_from_story_interactions',
    title: t('IBSOFT_INSTAGRAM_INBOUND.OPTIONS.STORY_INTERACTIONS.TITLE'),
    description: t(
      'IBSOFT_INSTAGRAM_INBOUND.OPTIONS.STORY_INTERACTIONS.DESCRIPTION'
    ),
  },
  {
    key: 'create_from_shared_reels_and_stories',
    title: t('IBSOFT_INSTAGRAM_INBOUND.OPTIONS.SHARED_REELS_AND_STORIES.TITLE'),
    description: t(
      'IBSOFT_INSTAGRAM_INBOUND.OPTIONS.SHARED_REELS_AND_STORIES.DESCRIPTION'
    ),
  },
  {
    key: 'create_from_shared_posts',
    title: t('IBSOFT_INSTAGRAM_INBOUND.OPTIONS.SHARED_POSTS.TITLE'),
    description: t('IBSOFT_INSTAGRAM_INBOUND.OPTIONS.SHARED_POSTS.DESCRIPTION'),
  },
]);

const applyPolicy = policy => {
  Object.keys(form).forEach(key => {
    form[key] = Boolean(policy[key]);
  });
};

const fetchPolicy = async () => {
  isFetching.value = true;
  hasLoadError.value = false;

  try {
    const { data } = await instagramInboundAPI.getInboxPolicy(props.inboxId);
    applyPolicy(data);
  } catch {
    hasLoadError.value = true;
    useAlert(t('IBSOFT_INSTAGRAM_INBOUND.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const savePolicy = async () => {
  isSaving.value = true;

  try {
    const { data } = await instagramInboundAPI.updateInboxPolicy(
      props.inboxId,
      { ...form }
    );
    applyPolicy(data);
    useAlert(t('IBSOFT_INSTAGRAM_INBOUND.SAVED'));
  } catch {
    useAlert(t('IBSOFT_INSTAGRAM_INBOUND.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

onMounted(fetchPolicy);
watch(() => props.inboxId, fetchPolicy);
</script>

<template>
  <section class="mx-6 max-w-4xl">
    <div v-if="isFetching" class="grid min-h-80 place-content-center">
      <Spinner />
    </div>

    <div
      v-else-if="hasLoadError"
      class="grid min-h-64 place-content-center gap-3 text-center"
    >
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ t('IBSOFT_INSTAGRAM_INBOUND.ERRORS.LOAD') }}
      </p>
      <Button
        :label="t('IBSOFT_INSTAGRAM_INBOUND.ACTIONS.RETRY')"
        color="slate"
        @click="fetchPolicy"
      />
    </div>

    <template v-else>
      <header class="mb-5">
        <h2 class="mb-1 text-heading-1 text-n-slate-12">
          {{ t('IBSOFT_INSTAGRAM_INBOUND.TITLE') }}
        </h2>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('IBSOFT_INSTAGRAM_INBOUND.DESCRIPTION') }}
        </p>
      </header>

      <section
        class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-1"
      >
        <div
          v-for="(option, index) in options"
          :key="option.key"
          class="flex items-start justify-between gap-6 p-4"
          :class="{ 'border-b border-n-weak': index < options.length - 1 }"
        >
          <div class="min-w-0">
            <h3 class="mb-1 text-heading-3 text-n-slate-12">
              {{ option.title }}
            </h3>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{ option.description }}
            </p>
          </div>
          <ToggleSwitch v-model="form[option.key]" class="mt-1 shrink-0" />
        </div>
      </section>

      <p class="mb-0 mt-3 text-body-small text-n-slate-11">
        {{ t('IBSOFT_INSTAGRAM_INBOUND.ACTIVE_CONVERSATION_NOTICE') }}
      </p>

      <div class="mt-5 flex justify-end">
        <Button
          :label="t('IBSOFT_INSTAGRAM_INBOUND.ACTIONS.SAVE')"
          :is-loading="isSaving"
          icon="i-lucide-save"
          @click="savePolicy"
        />
      </div>
    </template>
  </section>
</template>
