import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

import PageSizeSelect from '../components/PageSizeSelect.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('PageSizeSelect', () => {
  it('offers bounded page sizes and emits a numeric value', async () => {
    const wrapper = mount(PageSizeSelect, {
      props: { modelValue: 10 },
    });

    expect(wrapper.findAll('option').map(option => option.text())).toEqual([
      '10',
      '25',
      '50',
      '100',
    ]);

    await wrapper.get('select').setValue('50');

    expect(wrapper.emitted('update:modelValue')).toEqual([[50]]);

    await wrapper.get('button').trigger('click');

    expect(wrapper.emitted('update:modelValue')).toEqual([[50], [10]]);
  });
});
