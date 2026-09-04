# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    Current.reset
    Ibsoft::AccessControl::PermissionRequestCache.reset
  end
end
