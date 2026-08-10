import axios from 'axios';
import { actions } from '../../conversationStats';
import * as types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

vi.mock('@chatwoot/utils', () => ({
  debounce: vi.fn(fn => {
    return fn;
  }),
}));

describe('#actions', () => {
  beforeEach(() => {
    vi.useFakeTimers(); // Set up fake timers
    commit.mockClear();
  });

  afterEach(() => {
    vi.useRealTimers(); // Reset to real timers after each test
  });

  describe('#get', () => {
    it('sends correct mutations if API is success', async () => {
      axios.get.mockResolvedValue({ data: { meta: { mine_count: 1 } } });
      actions.get(
        { commit, state: { allCount: 0 } },
        { inboxId: 1, assigneeTpe: 'me', status: 'open' }
      );

      await vi.runAllTimersAsync();
      await vi.waitFor(() => expect(commit).toHaveBeenCalled());

      expect(commit.mock.calls).toEqual([
        [types.default.SET_CONV_TAB_META, { mine_count: 1 }],
      ]);
    });
    it('sends correct actions if API is error', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });
      actions.get(
        { commit, state: { allCount: 0 } },
        { inboxId: 1, assigneeTpe: 'me', status: 'open' }
      );
      expect(commit.mock.calls).toEqual([]);
    });
  });

  describe('#getImmediately', () => {
    it('fetches and commits without waiting for the debouncer', async () => {
      axios.get.mockResolvedValue({ data: { meta: { all_count: 4 } } });

      await actions.getImmediately(
        { commit },
        { assigneeType: 'all', status: 'open' }
      );

      expect(commit).toHaveBeenCalledWith(types.default.SET_CONV_TAB_META, {
        all_count: 4,
      });
    });

    it('does not let an older request overwrite a newer count', async () => {
      let resolveOlderRequest;
      let resolveNewerRequest;
      axios.get
        .mockImplementationOnce(
          () =>
            new Promise(resolve => {
              resolveOlderRequest = resolve;
            })
        )
        .mockImplementationOnce(
          () =>
            new Promise(resolve => {
              resolveNewerRequest = resolve;
            })
        );

      const olderRequest = actions.getImmediately(
        { commit },
        { status: 'open' }
      );
      const newerRequest = actions.getImmediately(
        { commit },
        { status: 'open' }
      );

      resolveNewerRequest({ data: { meta: { all_count: 2 } } });
      await newerRequest;
      resolveOlderRequest({ data: { meta: { all_count: 9 } } });
      await olderRequest;

      expect(commit).toHaveBeenCalledTimes(1);
      expect(commit).toHaveBeenCalledWith(types.default.SET_CONV_TAB_META, {
        all_count: 2,
      });
    });
  });

  describe('#set', () => {
    it('sends correct mutations', async () => {
      actions.set(
        { commit },
        { mine_count: 1, unassigned_count: 1, all_count: 2 }
      );
      expect(commit.mock.calls).toEqual([
        [
          types.default.SET_CONV_TAB_META,
          { mine_count: 1, unassigned_count: 1, all_count: 2 },
        ],
      ]);
    });
  });
});
