Rails.application.config.to_prepare do
  AgentBotListener.prepend(Ibsoft::AfterHours::AgentBotListenerExtension) unless
    AgentBotListener < Ibsoft::AfterHours::AgentBotListenerExtension
end
