class Ibsoft::AccessControl::PermissionCatalog
  CONVERSATION_PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
  ].freeze

  CORE_PERMISSIONS = (
    CONVERSATION_PERMISSIONS + %w[
      contact_manage
      report_manage
      knowledge_base_manage
    ]
  ).freeze

  IBSOFT_PERMISSIONS = %w[
    ibsoft_conversation_distribution_supervise
    ibsoft_chathub_settings_manage
  ].freeze

  PERMISSIONS = (CORE_PERMISSIONS + IBSOFT_PERMISSIONS).freeze

  GROUPS = {
    'conversation' => CONVERSATION_PERMISSIONS,
    'workspace' => %w[contact_manage report_manage knowledge_base_manage],
    'ibsoft' => IBSOFT_PERMISSIONS
  }.freeze

  def self.keys
    PERMISSIONS
  end

  def self.payload
    GROUPS.flat_map do |group, permissions|
      permissions.map do |permission|
        {
          key: permission,
          group: group
        }
      end
    end
  end
end
