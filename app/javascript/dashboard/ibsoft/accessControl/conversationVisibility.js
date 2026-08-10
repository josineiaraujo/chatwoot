const IBSOFT_ACCESS_ROLE_PERMISSION = 'ibsoft_access_role';
const AGENT_BOT_ASSIGNEE_TYPE = 'AgentBot';

export const canViewAgentBotConversationAsQueueProfile = (
  conversation,
  permissions = []
) => {
  return (
    permissions.includes(IBSOFT_ACCESS_ROLE_PERMISSION) &&
    conversation?.meta?.assignee_type === AGENT_BOT_ASSIGNEE_TYPE
  );
};
