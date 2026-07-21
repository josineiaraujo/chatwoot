import { beforeEach, describe, expect, it, vi } from 'vitest';

import ReplyBox from 'dashboard/components/widgets/conversation/ReplyBox.vue';

describe('ReplyBox assignment guard integration', () => {
  let context;

  beforeEach(() => {
    context = {
      isReplyAssignmentRequired: true,
      isReplyButtonDisabled: false,
      isEditorDisabled: false,
      isATwitterInbox: false,
      hasAttachments: 1,
      hasRecordedAudio: true,
      isMessageEmpty: false,
      message: 'Resposta',
      maxLength: 1000,
      showMentions: false,
      sendMessage: vi.fn(),
      hideWhatsappTemplatesModal: vi.fn(),
      hideContentTemplatesModal: vi.fn(),
      $store: { dispatch: vi.fn() },
    };
  });

  it('disables send even when an attachment or recorded audio is ready', () => {
    expect(ReplyBox.computed.isReplyButtonDisabled.call(context)).toBe(true);
  });

  it('does not clear or send the regular reply while assignment is required', () => {
    context.clearMessage = vi.fn();
    context.hideEmojiPicker = vi.fn();

    ReplyBox.methods.confirmOnSendReply.call(context);

    expect(context.sendMessage).not.toHaveBeenCalled();
    expect(context.clearMessage).not.toHaveBeenCalled();
  });

  it('blocks the final message dispatch as a concurrency safeguard', async () => {
    await ReplyBox.methods.sendMessage.call(context, {
      conversationId: 42,
      message: 'Resposta',
    });

    expect(context.$store.dispatch).not.toHaveBeenCalled();
  });

  it('blocks WhatsApp and content templates without closing their modals', async () => {
    await ReplyBox.methods.onSendWhatsAppReply.call(context, { message: 'A' });
    await ReplyBox.methods.onSendContentTemplateReply.call(context, {
      message: 'B',
    });

    expect(context.sendMessage).not.toHaveBeenCalled();
    expect(context.hideWhatsappTemplatesModal).not.toHaveBeenCalled();
    expect(context.hideContentTemplatesModal).not.toHaveBeenCalled();
  });

  it('ignores pasted files while assignment is required', () => {
    context.newConversationModalActive = false;
    context.onFileUpload = vi.fn();
    const event = {
      clipboardData: {
        files: [{ name: 'arquivo.pdf', size: 100, type: 'application/pdf' }],
      },
    };

    ReplyBox.methods.onPaste.call(context, event);

    expect(context.onFileUpload).not.toHaveBeenCalled();
  });
});
