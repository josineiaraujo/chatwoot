# == Schema Information
#
# Table name: ibsoft_internal_chat_attachments
#
#  id         :bigint           not null, primary key
#  file_type  :integer          default("file"), not null
#  metadata   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  message_id :bigint           not null
#
# Indexes
#
#  index_ibsoft_internal_chat_attachments_on_account_id  (account_id)
#  index_ibsoft_internal_chat_attachments_on_message_id  (message_id)
#
class Ibsoft::InternalChat::Attachment < ApplicationRecord
  include Rails.application.routes.url_helpers

  self.table_name = 'ibsoft_internal_chat_attachments'

  ACCEPTABLE_FILE_TYPES = ::Attachment::ACCEPTABLE_FILE_TYPES
  PREVIEW_RESIZE_TO_LIMIT = [640, 640].freeze

  belongs_to :account
  belongs_to :message,
             class_name: 'Ibsoft::InternalChat::Message',
             inverse_of: :attachments

  has_one_attached :file do |attachable|
    attachable.variant :internal_chat_preview,
                       resize_to_limit: PREVIEW_RESIZE_TO_LIMIT,
                       preprocessed: :previewable_media?
  end

  enum file_type: { file: 0, image: 1, audio: 2, video: 3 }

  validates :account, :message, :file_type, presence: true
  validate :acceptable_file
  validate :account_matches_message

  def payload
    {
      id: id,
      file_type: file_type,
      file_name: file.attached? ? file.filename.to_s : '',
      content_type: file.attached? ? file.content_type : '',
      byte_size: file.attached? ? file.byte_size : 0,
      url: file.attached? ? attachment_url : nil,
      preview_url: preview_url
    }
  end

  private

  def acceptable_file
    return unless file.attached?

    errors.add(:file, :too_large) if file.byte_size > maximum_file_upload_size.megabytes
    errors.add(:file, :invalid) unless media_file?(file.content_type.to_s) || ACCEPTABLE_FILE_TYPES.include?(file.content_type)
  end

  def account_matches_message
    errors.add(:account, :invalid) if message.present? && account_id != message.account_id
  end

  def preview_url
    return unless file.attached?
    return unless previewable_media?

    preview_attachment_url
  end

  def attachment_url
    api_v1_account_ibsoft_internal_chat_room_attachment_path(
      account_id: account_id,
      room_id: message.room_id,
      id: id
    )
  end

  def preview_attachment_url
    preview_api_v1_account_ibsoft_internal_chat_room_attachment_path(
      account_id: account_id,
      room_id: message.room_id,
      id: id
    )
  end

  def previewable_media?
    return true if image?

    video? && file.representable?
  end

  def media_file?(content_type)
    content_type.start_with?('image/', 'audio/', 'video/')
  end

  def maximum_file_upload_size
    limit_mb = GlobalConfigService.load('MAXIMUM_FILE_UPLOAD_SIZE', 40).to_i
    limit_mb.positive? ? limit_mb : 40
  end
end
