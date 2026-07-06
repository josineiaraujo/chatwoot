module Ibsoft::AccessControl::KnowledgeBasePolicy
  def index?
    can_manage_knowledge_base? || super
  end

  def update?
    can_manage_knowledge_base? || super
  end

  def show?
    can_manage_knowledge_base? || super
  end

  def edit?
    can_manage_knowledge_base? || super
  end

  def create?
    can_manage_knowledge_base? || super
  end

  def destroy?
    can_manage_knowledge_base? || super
  end

  def reorder?
    can_manage_knowledge_base? || super
  end

  def logo?
    can_manage_knowledge_base? || super
  end

  private

  def can_manage_knowledge_base?
    Ibsoft::AccessControl::PermissionResolver.permission?(account_user, 'knowledge_base_manage')
  end
end
