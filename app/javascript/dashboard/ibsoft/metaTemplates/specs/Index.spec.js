import { flushPromises, shallowMount } from '@vue/test-utils';
import { createMemoryHistory, createRouter } from 'vue-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import metaTemplatesAPI from '../api';
import Index from '../views/Index.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('shared/composables/useLocale', () => ({
  useLocale: () => ({
    resolvedLocale: { value: 'pt-BR' },
  }),
}));

vi.mock('../api', () => ({
  default: {
    getTemplates: vi.fn(),
  },
}));

const TemplateWorkspaceStub = {
  emits: ['close', 'saved'],
  template: `
    <button
      type="button"
      data-testid="complete-template"
      @click="$emit('saved')"
    ></button>
  `,
};

const createTestRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [
      {
        path: '/accounts/:accountId/meta-templates/:inboxId',
        name: 'ibsoft_meta_templates',
        component: Index,
      },
      {
        path: '/accounts/:accountId/meta-templates/:inboxId/new',
        name: 'ibsoft_meta_templates_new',
        component: Index,
      },
    ],
  });

describe('MetaTemplatesIndex', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    metaTemplatesAPI.getTemplates.mockResolvedValue({
      data: {
        templates: [],
        meta: { page: 1, per_page: 30, total: 0, total_pages: 1 },
        context: {},
      },
    });
  });

  it('closes the workspace before refreshing the list after submission', async () => {
    const router = createTestRouter();
    await router.push('/accounts/1/meta-templates/2/new');
    await router.isReady();

    const wrapper = shallowMount(Index, {
      global: {
        plugins: [router],
        stubs: {
          Button: true,
          Dialog: true,
          IbsoftSelect: true,
          Input: true,
          PaginationFooter: true,
          Spinner: true,
          TemplateWorkspace: TemplateWorkspaceStub,
        },
      },
    });
    await flushPromises();

    expect(wrapper.find('[data-testid="complete-template"]').exists()).toBe(
      true
    );

    await wrapper.get('[data-testid="complete-template"]').trigger('click');
    await flushPromises();

    expect(router.currentRoute.value.name).toBe('ibsoft_meta_templates');
    expect(wrapper.find('[data-testid="complete-template"]').exists()).toBe(
      false
    );
    expect(metaTemplatesAPI.getTemplates).toHaveBeenLastCalledWith('2', {
      query: undefined,
      status: undefined,
      category: undefined,
      language: undefined,
      page: 1,
      per_page: 30,
      refresh: true,
    });
  });
});
