class Api::V1::Accounts::Ibsoft::MetaTemplates::MediaUploadsController <
  Api::V1::Accounts::Ibsoft::MetaTemplates::BaseController
  def create
    result = Ibsoft::MetaTemplates::MediaUploader.new(
      channel: inbox.channel,
      file: params.require(:file)
    ).call

    render json: result, status: :created
  end
end
