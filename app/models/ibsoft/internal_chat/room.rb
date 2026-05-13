# == Schema Information
#
# Table name: ibsoft_internal_chat_rooms
#
#  id            :bigint           not null, primary key
#  direct_key    :string
#  name          :string
#  room_type     :integer          default("room"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  created_by_id :bigint           not null
#
# Indexes
#
#  index_ibsoft_internal_chat_rooms_on_account_id                 (account_id)
#  index_ibsoft_internal_chat_rooms_on_account_id_and_direct_key  (account_id,direct_key) UNIQUE WHERE (direct_key IS NOT NULL)
#  index_ibsoft_internal_chat_rooms_on_account_id_and_room_type   (account_id,room_type)
#  index_ibsoft_internal_chat_rooms_on_created_by_id              (created_by_id)
#
class Ibsoft::InternalChat::Room < ApplicationRecord
  include Rails.application.routes.url_helpers

  self.table_name = 'ibsoft_internal_chat_rooms'

  ALLOWED_COVER_IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User'

  has_one_attached :cover_image

  has_many :memberships,
           class_name: 'Ibsoft::InternalChat::Membership',
           dependent: :destroy,
           inverse_of: :room
  has_many :members, through: :memberships, source: :user
  has_many :messages,
           class_name: 'Ibsoft::InternalChat::Message',
           dependent: :destroy,
           inverse_of: :room

  enum room_type: { room: 0, direct: 1 }

  validates :account, :created_by, :room_type, presence: true
  validates :name, presence: true, if: :room?
  validates :direct_key, presence: true, uniqueness: { scope: :account_id }, if: :direct?
  validate :acceptable_cover_image, if: -> { cover_image.attached? }
  validate :direct_rooms_do_not_have_names

  scope :visible_for, lambda { |user|
    joins(:memberships)
      .where(ibsoft_internal_chat_memberships: { user_id: user.id })
      .distinct
  }

  def display_name_for(user)
    return name if room?
    return I18n.t('ibsoft_internal_chat.direct_room_fallback') unless room_member?(user)

    other_member = members.detect { |member| member.id != user.id }
    return member_display_name(other_member) if other_member.present?

    direct_room_display_name
  end

  def payload_for(user)
    visible_member = room_member?(user)

    {
      id: id,
      room_type: room_type,
      name: name,
      display_name: display_name_for(user),
      created_by_id: created_by_id,
      cover_image_url: cover_image_url,
      permissions: permissions_for(user),
      unread_count: unread_count_for(user),
      members: visible_member ? memberships.filter_map { |membership| member_payload(membership) } : [],
      last_message: visible_member ? last_message&.payload : nil,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end

  def last_message
    messages.visible.order(created_at: :desc).first
  end

  def cover_image_url
    return '' unless cover_image.attached?
    return url_for(cover_image) unless cover_image.representable?

    url_for(cover_image.representation(resize_to_fill: [250, 250]))
  end

  def unread_count_for(user)
    membership = memberships.detect { |item| item.user_id == user.id } || memberships.find_by(user_id: user.id)
    return 0 unless membership

    unread_messages = messages.visible.where.not(sender_id: user.id)
    unread_messages = unread_messages.where('created_at > ?', membership.last_read_at) if membership.last_read_at.present?
    unread_messages.count
  end

  private

  def direct_rooms_do_not_have_names
    errors.add(:name, :blank) if direct? && name.present?
  end

  def permissions_for(user)
    room_member = room_member?(user)
    room_creator = room_creator?(user)
    account_admin = account_admin?(user)

    {
      update_cover_image: room? && room_member,
      manage_members: room? && room_member && room_creator,
      destroy: account_admin || (room? && room_creator)
    }
  end

  def direct_room_display_name
    member_names = members.filter_map { |member| member_display_name(member) }
    return member_names.join(' / ') if member_names.any?

    I18n.t('ibsoft_internal_chat.direct_room_fallback')
  end

  def member_display_name(member)
    member&.available_name || member&.name
  end

  def room_member?(user)
    memberships.any? { |membership| membership.user_id == user.id }
  end

  def room_creator?(user)
    created_by_id == user.id
  end

  def account_admin?(user)
    account.account_users.any? do |account_user|
      account_user.user_id == user.id && account_user.administrator?
    end
  end

  def acceptable_cover_image
    errors.add(:cover_image, :too_large) if cover_image.byte_size > 15.megabytes

    return if ALLOWED_COVER_IMAGE_CONTENT_TYPES.include?(cover_image.content_type)

    errors.add(:cover_image, :invalid)
  end

  def member_payload(membership)
    member = membership.user
    return if member.blank?

    avatar_url = member.avatar_url

    {
      membership_id: membership.id,
      id: member.id,
      name: member.name,
      available_name: member.available_name,
      email: member.email,
      avatar_url: avatar_url,
      thumbnail: avatar_url,
      availability_status: member.availability_status,
      role: membership.role,
      is_creator: member.id == created_by_id
    }
  end
end
