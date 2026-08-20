require 'rails_helper'

RSpec.describe Ibsoft::ExternalMessaging::OrderUpdateTemplateCatalog do
  subject(:template_catalog) do
    described_class.new(endpoint: endpoint, catalog: catalog)
  end

  let(:endpoint) { instance_double(Ibsoft::ExternalMessaging::Endpoint) }
  let(:catalog) { instance_double(Ibsoft::MetaTemplates::Catalog) }

  let(:template_attributes) do
    {
      'id' => 'template-1',
      'name' => 'atualizacao_fatura',
      'language' => 'pt_BR',
      'status' => 'APPROVED',
      'category' => 'UTILITY',
      'sub_category' => 'ORDER_STATUS',
      'parameter_format' => 'NAMED',
      'components' => [
        {
          'type' => 'BODY',
          'text' => '{{mensagem_status}}',
          'example' => {
            'body_text_named_params' => [
              { 'param_name' => 'mensagem_status', 'example' => 'Pagamento confirmado.' }
            ]
          }
        }
      ]
    }
  end

  def template(attributes = {})
    template_attributes.deep_merge(attributes)
  end

  it 'lists approved order-status templates with zero or one body variable' do
    without_variable = template(
      'id' => 'template-2',
      'name' => 'status_sem_variavel',
      'components' => [{ 'type' => 'BODY', 'text' => 'Sua fatura foi atualizada.' }]
    )
    allow(catalog).to receive(:list).and_return([without_variable, template])

    expect(template_catalog.list).to contain_exactly(
      {
        'id' => 'template-1',
        'name' => 'atualizacao_fatura',
        'language' => 'pt_BR',
        'parameter_format' => 'NAMED',
        'body_parameter' => {
          'format' => 'named',
          'key' => 'mensagem_status'
        }
      },
      {
        'id' => 'template-2',
        'name' => 'status_sem_variavel',
        'language' => 'pt_BR',
        'parameter_format' => 'NAMED',
        'body_parameter' => nil
      }
    )
  end

  it 'rejects templates that cannot be filled deterministically' do
    allow(catalog).to receive(:list).and_return(
      [
        template('status' => 'PENDING'),
        template('sub_category' => 'CUSTOM'),
        template('components' => [{ 'type' => 'BODY', 'text' => '{{one}} {{two}}' }]),
        template('components' => [{ 'type' => 'BODY', 'text' => '{{InvalidName}}' }]),
        template(
          'components' => [
            { 'type' => 'BODY', 'text' => '{{mensagem_status}}' },
            { 'type' => 'BUTTONS', 'buttons' => [{ 'type' => 'URL', 'url' => 'https://example.com/{{1}}' }] }
          ]
        )
      ]
    )

    expect(template_catalog.list).to be_empty
  end

  it 'finds only templates accepted by the normalized catalog' do
    allow(catalog).to receive(:list).and_return([template])

    expect(template_catalog.find('template-1')).to include('name' => 'atualizacao_fatura')
    expect(template_catalog.find('missing')).to be_nil
  end
end
