class Ibsoft::AgentProvisioning::AvatarAttacher
  attr_reader :user, :avatar

  def initialize(user:, avatar:)
    @user = user
    @avatar = avatar
  end

  def perform
    return if avatar.blank?

    avatar.tempfile.rewind if avatar.respond_to?(:tempfile)
    user.avatar.attach(
      io: avatar.tempfile,
      filename: avatar.original_filename,
      content_type: avatar.content_type
    )
    user.save!
  end
end
