import { shallowMount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import HistoryPaginationFooter from '../components/HistoryPaginationFooter.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values = {}) => {
      if (key === 'PAGINATION_FOOTER.SHOWING') {
        return `${values.startItem}-${values.endItem}/${values.totalItems}`;
      }

      if (key === 'PAGINATION_FOOTER.CURRENT_PAGE_INFO') {
        return `de ${values.totalPages} páginas`;
      }

      return key;
    },
  }),
}));

vi.mock('shared/composables/useNumberFormatter', () => ({
  useNumberFormatter: () => ({
    formatCompactNumber: value => String(value),
    formatFullNumber: value => String(value),
  }),
}));

const mountComponent = () =>
  shallowMount(HistoryPaginationFooter, {
    props: {
      currentPage: 1,
      totalItems: 35,
      itemsPerPage: 10,
      pageSizeOptions: [10, 25, 30, 50],
      defaultPageSize: 30,
    },
    global: {
      stubs: {
        Button: {
          props: ['disabled'],
          emits: ['click'],
          template:
            '<button type="button" :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
        },
        PageSizeSelect: {
          props: ['modelValue', 'options'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(\'update:modelValue\', Number($event.target.value))"><option v-for="option in options" :key="option" :value="option">{{ option }}</option></select>',
        },
      },
    },
  });

describe('HistoryPaginationFooter', () => {
  it('keeps page size, refresh and navigation in the same footer', async () => {
    const wrapper = mountComponent();
    const footer = wrapper.get('[data-testid="history-pagination-footer"]');

    expect(footer.text()).toContain('1-10/35');
    expect(footer.text()).toContain('de 4 páginas');
    expect(footer.find('[data-testid="history-page-size"]').exists()).toBe(
      true
    );
    expect(footer.find('[data-testid="history-refresh"]').exists()).toBe(true);
    expect(footer.find('[data-testid="history-next-page"]').exists()).toBe(
      true
    );

    await footer.get('[data-testid="history-page-size"]').setValue('25');
    await footer.get('[data-testid="history-refresh"]').trigger('click');
    await footer.get('[data-testid="history-next-page"]').trigger('click');
    await footer.get('[data-testid="history-last-page"]').trigger('click');

    expect(wrapper.emitted('update:itemsPerPage')).toEqual([[25]]);
    expect(wrapper.emitted('refresh')).toHaveLength(1);
    expect(wrapper.emitted('update:currentPage')).toEqual([[2], [4]]);
  });

  it('disables backward navigation on the first page', () => {
    const wrapper = mountComponent();

    expect(
      wrapper.get('[data-testid="history-first-page"]').attributes('disabled')
    ).toBeDefined();
    expect(
      wrapper
        .get('[data-testid="history-previous-page"]')
        .attributes('disabled')
    ).toBeDefined();
  });
});
