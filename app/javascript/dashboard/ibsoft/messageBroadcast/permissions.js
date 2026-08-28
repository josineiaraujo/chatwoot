export const IBSOFT_MESSAGE_BROADCAST_PERMISSION =
  'ibsoft_message_broadcast_manage';

export const canManageMessageBroadcast = account =>
  Boolean(
    account?.role === 'administrator' ||
      account?.permissions?.includes(IBSOFT_MESSAGE_BROADCAST_PERMISSION)
  );
