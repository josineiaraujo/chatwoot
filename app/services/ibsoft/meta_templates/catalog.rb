class Ibsoft::MetaTemplates::Catalog
  CACHE_TTL = 15.minutes

  def initialize(inbox, client: nil)
    @inbox = inbox
    @channel = inbox.channel
    @client = client || Ibsoft::MetaTemplates::Client.new(@channel)
  end

  def list(force: false)
    refresh! if force || stale?
    cached_templates
  end

  def find(template_id)
    cached = cached_templates.find { |template| template['id'].to_s == template_id.to_s }
    return cached if cached.present?

    client.template(template_id)
  end

  def create(payload)
    response = client.create_template(payload)
    mutation_result(response, payload['name'])
  end

  def update(template_id, payload)
    response = client.update_template(template_id, payload)
    mutation_result(response, nil, template_id)
  end

  def delete(template_id)
    client.delete_template(template_id)
    refresh_after_mutation
    true
  end

  def refresh!
    templates = client.list_templates
    update_waba_caches(templates)
    templates
  end

  private

  attr_reader :inbox, :channel, :client

  def stale?
    channel.message_templates_last_updated.blank? ||
      channel.message_templates_last_updated < CACHE_TTL.ago ||
      !channel.message_templates.is_a?(Array)
  end

  def cached_templates
    Array(channel.reload.message_templates).filter_map do |template|
      template.to_h.deep_stringify_keys if template.respond_to?(:to_h)
    end
  end

  def mutation_result(response, template_name = nil, template_id = nil)
    refreshed = refresh_after_mutation
    template = if refreshed
                 cached_templates.find do |candidate|
                   (template_id.present? && candidate['id'].to_s == template_id.to_s) ||
                     (template_name.present? && candidate['name'].to_s == template_name.to_s)
                 end
               end

    {
      template: template || response,
      cache_refreshed: refreshed
    }
  end

  def refresh_after_mutation
    refresh!
    true
  rescue Ibsoft::MetaTemplates::Client::Error
    invalidate_current_cache
    false
  end

  def update_waba_caches(templates)
    related_channels.each do |related_channel|
      # Avoid provider credential validation and a second remote request.
      # rubocop:disable Rails/SkipsModelValidations
      related_channel.update_columns(
        message_templates: templates,
        message_templates_last_updated: Time.current
      )
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def invalidate_current_cache
    # rubocop:disable Rails/SkipsModelValidations
    channel.update_column(:message_templates_last_updated, nil)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def related_channels
    account = inbox.account
    business_account_id = channel.provider_config['business_account_id'].to_s

    account.inboxes.includes(:channel).filter_map do |candidate_inbox|
      candidate = candidate_inbox.channel
      next unless candidate.is_a?(Channel::Whatsapp)
      next unless candidate.provider == 'whatsapp_cloud'
      next unless candidate.provider_config['business_account_id'].to_s == business_account_id

      candidate
    end
  end
end
