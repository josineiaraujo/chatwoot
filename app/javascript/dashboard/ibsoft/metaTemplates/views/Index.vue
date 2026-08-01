<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import PaginationFooter from 'dashboard/components-next/pagination/PaginationFooter.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import { useAlert } from 'dashboard/composables';
import { useLocale } from 'shared/composables/useLocale';
import metaTemplatesAPI from '../api';
import TemplateWorkspace from '../components/TemplateWorkspace.vue';
import { sortTemplatesByMostRecent } from '../templateModel';

const { t } = useI18n();
const { resolvedLocale } = useLocale();
const route = useRoute();
const router = useRouter();

const templates = ref([]);
const context = ref({});
const meta = ref({ page: 1, per_page: 30, total: 0, total_pages: 1 });
const query = ref('');
const status = ref('');
const category = ref('');
const language = ref('');
const isLoading = ref(false);
const isRefreshing = ref(false);
const templateToDelete = ref(null);
const deleteDialog = ref(null);
let searchTimer;

const inboxId = computed(() => route.params.inboxId);
const templateId = computed(() => route.params.templateId || '');
const editorOpen = computed(() =>
  ['ibsoft_meta_templates_new', 'ibsoft_meta_templates_edit'].includes(
    route.name
  )
);
const statusLabels = computed(() => ({
  APPROVED: t('IBSOFT_META_TEMPLATES.STATUS.APPROVED'),
  PENDING: t('IBSOFT_META_TEMPLATES.STATUS.PENDING'),
  REJECTED: t('IBSOFT_META_TEMPLATES.STATUS.REJECTED'),
  PAUSED: t('IBSOFT_META_TEMPLATES.STATUS.PAUSED'),
  DISABLED: t('IBSOFT_META_TEMPLATES.STATUS.DISABLED'),
  UNKNOWN: t('IBSOFT_META_TEMPLATES.STATUS.UNKNOWN'),
}));
const statusOptions = computed(() =>
  ['APPROVED', 'PENDING', 'REJECTED', 'PAUSED', 'DISABLED'].map(value => ({
    value,
    label: statusLabels.value[value],
  }))
);
const categoryLabels = computed(() => ({
  MARKETING: t('IBSOFT_META_TEMPLATES.CATEGORY.MARKETING'),
  UTILITY: t('IBSOFT_META_TEMPLATES.CATEGORY.UTILITY'),
  AUTHENTICATION: t('IBSOFT_META_TEMPLATES.CATEGORY.AUTHENTICATION'),
}));
const categoryOptions = computed(() =>
  ['MARKETING', 'UTILITY', 'AUTHENTICATION'].map(value => ({
    value,
    label: categoryLabels.value[value],
  }))
);
const languageOptions = computed(() =>
  ['pt_BR', 'pt_PT', 'en_US', 'en_GB', 'es', 'es_AR'].map(value => ({
    value,
    label: value,
  }))
);

const formatDate = value => {
  if (!value) return t('IBSOFT_META_TEMPLATES.STATUS.UNKNOWN');
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return t('IBSOFT_META_TEMPLATES.STATUS.UNKNOWN');
  }

  try {
    return new Intl.DateTimeFormat(resolvedLocale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(date);
  } catch {
    return new Intl.DateTimeFormat('en', {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(date);
  }
};

const statusLabel = value =>
  statusLabels.value[value] || statusLabels.value.UNKNOWN;

const categoryLabel = value => categoryLabels.value[value] || value;

const statusClass = value =>
  ({
    APPROVED: 'bg-n-teal-3 text-n-teal-11',
    PENDING: 'bg-n-amber-3 text-n-amber-11',
    REJECTED: 'bg-n-ruby-3 text-n-ruby-11',
    PAUSED: 'bg-n-orange-3 text-n-orange-11',
    DISABLED: 'bg-n-slate-3 text-n-slate-11',
  })[value] || 'bg-n-slate-3 text-n-slate-11';

const fetchTemplates = async ({ refresh = false } = {}) => {
  isLoading.value = !refresh;
  isRefreshing.value = refresh;
  try {
    const { data } = await metaTemplatesAPI.getTemplates(inboxId.value, {
      query: query.value || undefined,
      status: status.value || undefined,
      category: category.value || undefined,
      language: language.value || undefined,
      page: meta.value.page,
      per_page: meta.value.per_page,
      refresh: refresh || undefined,
    });
    templates.value = sortTemplatesByMostRecent(data.templates || []);
    meta.value = data.meta;
    context.value = data.context || {};
    if (refresh) useAlert(t('IBSOFT_META_TEMPLATES.SUCCESS.SYNCED'));
  } catch (error) {
    const message = error.response?.data?.message;
    useAlert(message || t('IBSOFT_META_TEMPLATES.ERRORS.LOAD'));
  } finally {
    isLoading.value = false;
    isRefreshing.value = false;
  }
};

const openCreate = () =>
  router.push({
    name: 'ibsoft_meta_templates_new',
    params: { inboxId: inboxId.value },
  });

const openEdit = template =>
  router.push({
    name: 'ibsoft_meta_templates_edit',
    params: { inboxId: inboxId.value, templateId: template.id },
  });

const closeEditor = () =>
  router.push({
    name: 'ibsoft_meta_templates',
    params: { inboxId: inboxId.value },
  });

const handleSaved = async () => {
  await closeEditor();
  await nextTick();
  await fetchTemplates({ refresh: true });
};

const confirmDelete = template => {
  templateToDelete.value = template;
  deleteDialog.value?.open();
};

const deleteTemplate = async () => {
  if (!templateToDelete.value) return;
  try {
    await metaTemplatesAPI.deleteTemplate(
      inboxId.value,
      templateToDelete.value.id
    );
    deleteDialog.value?.close();
    templateToDelete.value = null;
    useAlert(t('IBSOFT_META_TEMPLATES.SUCCESS.DELETED'));
    await fetchTemplates();
  } catch (error) {
    const message = error.response?.data?.message;
    useAlert(message || t('IBSOFT_META_TEMPLATES.ERRORS.DELETE'));
  }
};

const changePage = page => {
  meta.value.page = page;
  fetchTemplates();
};

watch([status, category, language], () => {
  meta.value.page = 1;
  fetchTemplates();
});

watch(query, () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    meta.value.page = 1;
    fetchTemplates();
  }, 300);
});

onMounted(fetchTemplates);
onBeforeUnmount(() => clearTimeout(searchTimer));
</script>

<template>
  <section
    class="flex h-full min-w-0 flex-1 flex-col overflow-y-auto bg-n-background"
  >
    <div class="mx-auto grid w-full max-w-7xl gap-5 p-4 md:p-6">
      <header class="flex flex-wrap items-start justify-between gap-4">
        <div class="min-w-0">
          <router-link
            :to="{
              name: 'ibsoft_chathub_settings',
              query: { section: 'channels' },
            }"
            class="mb-3 inline-flex items-center gap-2 text-sm text-n-brand hover:underline"
          >
            <i class="i-lucide-arrow-left size-4" />
            {{ t('IBSOFT_META_TEMPLATES.BACK') }}
          </router-link>
          <h1 class="m-0 text-heading-1 text-n-slate-12">
            {{ t('IBSOFT_META_TEMPLATES.TITLE') }}
          </h1>
          <p
            v-if="context.inbox_name"
            class="mb-0 mt-1 text-sm text-n-slate-11"
          >
            {{
              t('IBSOFT_META_TEMPLATES.CHANNEL_CONTEXT', {
                name: context.inbox_name,
              })
            }}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <Button
            icon="i-lucide-refresh-cw"
            color="slate"
            variant="outline"
            :is-loading="isRefreshing"
            :label="t('IBSOFT_META_TEMPLATES.REFRESH')"
            @click="fetchTemplates({ refresh: true })"
          />
          <Button
            icon="i-lucide-plus"
            :label="t('IBSOFT_META_TEMPLATES.NEW')"
            @click="openCreate"
          />
        </div>
      </header>

      <section
        class="overflow-hidden rounded-lg border border-n-weak bg-n-solid-2"
      >
        <div class="grid gap-3 border-b border-n-weak p-4">
          <Input
            v-model="query"
            :placeholder="t('IBSOFT_META_TEMPLATES.SEARCH')"
            custom-input-class="!pl-9"
          >
            <template #prefix>
              <i
                class="pointer-events-none absolute left-3 top-3 i-lucide-search size-4 text-n-slate-10"
              />
            </template>
          </Input>
          <div class="grid min-w-0 gap-3 lg:grid-cols-3">
            <IbsoftSelect v-model="status">
              <option value="">
                {{ t('IBSOFT_META_TEMPLATES.FILTERS.ALL_STATUSES') }}
              </option>
              <option
                v-for="option in statusOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </IbsoftSelect>
            <IbsoftSelect v-model="category">
              <option value="">
                {{ t('IBSOFT_META_TEMPLATES.FILTERS.ALL_CATEGORIES') }}
              </option>
              <option
                v-for="option in categoryOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </IbsoftSelect>
            <IbsoftSelect v-model="language">
              <option value="">
                {{ t('IBSOFT_META_TEMPLATES.FILTERS.ALL_LANGUAGES') }}
              </option>
              <option
                v-for="option in languageOptions"
                :key="option.value"
                :value="option.value"
              >
                {{ option.label }}
              </option>
            </IbsoftSelect>
          </div>
        </div>

        <div v-if="isLoading" class="grid min-h-80 place-content-center">
          <Spinner />
        </div>

        <div
          v-else-if="!templates.length"
          class="grid min-h-80 place-content-center p-8 text-center"
        >
          <i
            class="i-lucide-layout-template mx-auto mb-3 size-8 text-n-slate-9"
          />
          <p class="m-0 text-sm text-n-slate-11">
            {{
              query || status || category || language
                ? t('IBSOFT_META_TEMPLATES.NO_RESULTS')
                : t('IBSOFT_META_TEMPLATES.EMPTY')
            }}
          </p>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full min-w-[52rem] border-collapse text-left text-sm">
            <thead class="bg-n-alpha-1 text-xs font-medium text-n-slate-11">
              <tr>
                <th class="px-4 py-3">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.NAME') }}
                </th>
                <th class="px-4 py-3">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.CATEGORY') }}
                </th>
                <th class="px-4 py-3">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.LANGUAGE') }}
                </th>
                <th class="px-4 py-3">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.STATUS') }}
                </th>
                <th class="px-4 py-3">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.DATE') }}
                </th>
                <th class="w-28 px-4 py-3 text-right">
                  {{ t('IBSOFT_META_TEMPLATES.TABLE.ACTIONS') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="template in templates"
                :key="template.id"
                class="hover:bg-n-alpha-1"
              >
                <td class="px-4 py-3">
                  <p class="m-0 max-w-sm truncate font-medium text-n-slate-12">
                    {{ template.name }}
                  </p>
                  <p
                    v-if="
                      template.rejected_reason &&
                      template.rejected_reason !== 'NONE'
                    "
                    class="m-0 mt-1 max-w-sm truncate text-xs text-n-ruby-10"
                  >
                    {{ template.rejected_reason }}
                  </p>
                </td>
                <td class="px-4 py-3 text-n-slate-11">
                  {{ categoryLabel(template.category) }}
                </td>
                <td class="px-4 py-3 text-n-slate-11">
                  {{ template.language }}
                </td>
                <td class="px-4 py-3">
                  <span
                    class="inline-flex rounded-md px-2 py-1 text-xs font-medium"
                    :class="statusClass(template.status)"
                  >
                    {{ statusLabel(template.status) }}
                  </span>
                </td>
                <td class="whitespace-nowrap px-4 py-3 text-n-slate-11">
                  {{ formatDate(template.last_updated_time) }}
                </td>
                <td class="px-4 py-3">
                  <div class="flex justify-end gap-1">
                    <Button
                      v-tooltip.top="t('IBSOFT_META_TEMPLATES.EDIT')"
                      icon="i-lucide-pencil"
                      color="slate"
                      variant="ghost"
                      size="sm"
                      :aria-label="t('IBSOFT_META_TEMPLATES.EDIT')"
                      @click="openEdit(template)"
                    />
                    <Button
                      v-tooltip.top="t('IBSOFT_META_TEMPLATES.DELETE')"
                      icon="i-lucide-trash-2"
                      color="ruby"
                      variant="ghost"
                      size="sm"
                      :aria-label="t('IBSOFT_META_TEMPLATES.DELETE')"
                      @click="confirmDelete(template)"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <PaginationFooter
          v-if="meta.total > meta.per_page"
          :current-page="meta.page"
          :total-items="meta.total"
          :items-per-page="meta.per_page"
          @update:current-page="changePage"
        />
      </section>

      <p
        v-if="context.last_synced_at"
        class="m-0 text-right text-xs text-n-slate-10"
      >
        {{
          t('IBSOFT_META_TEMPLATES.LAST_SYNC', {
            date: formatDate(context.last_synced_at),
          })
        }}
      </p>
    </div>

    <TemplateWorkspace
      v-if="editorOpen"
      :key="templateId || 'new'"
      :inbox-id="inboxId"
      :template-id="templateId"
      @close="closeEditor"
      @saved="handleSaved"
    />

    <Dialog
      ref="deleteDialog"
      type="alert"
      :title="t('IBSOFT_META_TEMPLATES.DELETE_TITLE')"
      :description="
        t('IBSOFT_META_TEMPLATES.DELETE_MESSAGE', {
          name: templateToDelete?.name,
        })
      "
      :confirm-button-label="t('IBSOFT_META_TEMPLATES.DELETE_CONFIRM')"
      :cancel-button-label="t('IBSOFT_META_TEMPLATES.DELETE_CANCEL')"
      @confirm="deleteTemplate"
      @close="templateToDelete = null"
    />
  </section>
</template>
