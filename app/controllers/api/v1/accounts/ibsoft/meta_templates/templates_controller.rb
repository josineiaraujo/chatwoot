class Api::V1::Accounts::Ibsoft::MetaTemplates::TemplatesController <
  Api::V1::Accounts::Ibsoft::MetaTemplates::BaseController
  def index
    templates = template_catalog.list(force: ActiveModel::Type::Boolean.new.cast(params[:refresh]))
    templates = filter_templates(templates)
    templates = sort_templates(templates)

    render json: collection_response(templates)
  end

  def show
    render json: {
      template: template_catalog.find(params[:id]),
      context: channel_context
    }
  end

  def create
    payload = Ibsoft::MetaTemplates::TemplatePayload.new(template_attributes).create_payload
    result = template_catalog.create(payload)

    render json: {
      template: result[:template],
      cache_refreshed: result[:cache_refreshed],
      context: channel_context
    }, status: :created
  end

  def update
    payload = Ibsoft::MetaTemplates::TemplatePayload.new(template_attributes).update_payload
    result = template_catalog.update(params[:id], payload)

    render json: {
      template: result[:template],
      cache_refreshed: result[:cache_refreshed],
      context: channel_context
    }
  end

  def destroy
    template_catalog.delete(params[:id])
    head :no_content
  end

  private

  def template_attributes
    params.require(:template).to_unsafe_h
  end

  def filter_templates(templates)
    templates.select do |template|
      template_matches_filters?(template)
    end
  end

  def template_matches_filters?(template)
    filter_values.all? do |field, value|
      value.blank? || normalized_template_value(template, field).include?(value)
    end
  end

  def filter_values
    {
      'name' => params[:query].to_s.strip.downcase,
      'status' => params[:status].to_s.upcase,
      'category' => params[:category].to_s.upcase,
      'language' => params[:language].to_s
    }
  end

  def normalized_template_value(template, field)
    value = template[field].to_s
    field == 'name' ? value.downcase : value
  end

  def sort_templates(templates)
    templates.sort_by do |template|
      updated_at = template_updated_at(template)

      [
        updated_at.present? ? 0 : 1,
        updated_at.present? ? -updated_at.to_f : 0,
        template['name'].to_s.downcase,
        template['language'].to_s.downcase
      ]
    end
  end

  def template_updated_at(template)
    value = template['last_updated_time']
    return if value.blank?
    return Time.zone.at(value) if value.is_a?(Numeric)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def collection_response(templates)
    page = params.fetch(:page, 1).to_i.clamp(1, 1_000_000)
    per_page = params.fetch(:per_page, 30).to_i.clamp(10, 100)
    offset = (page - 1) * per_page

    {
      templates: templates.slice(offset, per_page) || [],
      meta: {
        page: page,
        per_page: per_page,
        total: templates.size,
        total_pages: [(templates.size.to_f / per_page).ceil, 1].max
      },
      context: channel_context
    }
  end

  def channel_context
    channel = inbox.channel
    {
      inbox_id: inbox.id,
      inbox_name: inbox.name,
      phone_number: channel.phone_number,
      business_account_id: channel.provider_config['business_account_id'],
      last_synced_at: channel.message_templates_last_updated
    }
  end
end
