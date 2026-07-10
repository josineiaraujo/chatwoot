import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import IbsoftSelect from 'dashboard/ibsoft/components/IbsoftSelect.vue';
import LookupMultiSelect from '../components/LookupMultiSelect.vue';
import LookupSingleSelect from '../components/LookupSingleSelect.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

describe('Message broadcast lookup selects', () => {
  it('keeps lookup triggers constrained to their grid column', () => {
    const singleWrapper = mount(LookupSingleSelect, {
      props: {
        modelValue: '10',
        options: [{ value: '10', label: 'DF - Distrito Federal' }],
        placeholder: 'Selecionar',
        searchPlaceholder: 'Pesquisar',
        emptyState: 'Vazio',
        loadingLabel: 'Carregando',
      },
    });
    const multiWrapper = mount(LookupMultiSelect, {
      props: {
        modelValue: ['15'],
        options: [{ value: '15', label: 'OLT DATACOM' }],
        placeholder: 'Selecionar',
        selectedLabel: '1 selecionado',
        searchPlaceholder: 'Pesquisar',
        emptyState: 'Vazio',
        loadingLabel: 'Carregando',
      },
    });

    [singleWrapper, multiWrapper].forEach(wrapper => {
      const container = wrapper.find('[data-testid^="lookup-"]');
      const trigger = container.get('button');

      expect(container.classes()).toEqual(
        expect.arrayContaining(['box-border', 'min-w-0', 'w-full'])
      );
      expect(trigger.classes()).toEqual(
        expect.arrayContaining(['box-border', 'min-w-0', 'w-full'])
      );
    });
  });

  it('clears a multi selection from the trigger button', async () => {
    const wrapper = mount(LookupMultiSelect, {
      props: {
        modelValue: ['15'],
        options: [{ value: '15', label: 'OLT DATACOM' }],
        placeholder: 'Selecionar',
        selectedLabel: '1 selecionado',
        searchPlaceholder: 'Pesquisar',
        emptyState: 'Vazio',
        loadingLabel: 'Carregando',
      },
    });

    await wrapper
      .find(
        '[aria-label="IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.CLEAR_SELECTION"]'
      )
      .trigger('click');

    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual([[]]);
  });

  it('clears a single lookup selection from the trigger button', async () => {
    const wrapper = mount(LookupSingleSelect, {
      props: {
        modelValue: '10',
        options: [{ value: '10', label: 'Bahia' }],
        placeholder: 'Selecionar',
        searchPlaceholder: 'Pesquisar',
        emptyState: 'Vazio',
        loadingLabel: 'Carregando',
      },
    });

    await wrapper
      .find(
        '[aria-label="IBSOFT_THEME.MESSAGE_BROADCAST.LOOKUPS.CLEAR_SELECTION"]'
      )
      .trigger('click');

    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['']);
  });

  it('clears a native Ibsoft select value from the wrapper button', async () => {
    const wrapper = mount(IbsoftSelect, {
      props: {
        modelValue: 'active',
      },
      slots: {
        default: `
          <option value="">Qualquer status</option>
          <option value="active">Ativo</option>
        `,
      },
      global: {
        stubs: { Icon: true },
      },
    });

    await wrapper
      .find('[aria-label="IBSOFT_THEME.COMMON.CLEAR_SELECTION"]')
      .trigger('click');

    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual(['']);
  });

  it('uses the same full-width box model for native Ibsoft selects', () => {
    const wrapper = mount(IbsoftSelect, {
      slots: {
        default: '<option value="">Qualquer status</option>',
      },
      global: {
        stubs: { Icon: true },
      },
    });

    expect(wrapper.classes()).toEqual(
      expect.arrayContaining(['box-border', 'min-w-0', 'w-full'])
    );
    expect(wrapper.get('select').classes()).toEqual(
      expect.arrayContaining(['!mb-0', 'box-border', 'w-full'])
    );
  });
});
