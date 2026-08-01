import { describe, expect, it } from 'vitest';

import {
  CATEGORY_MODELS,
  convertTemplateVariableFormat,
  createEmptyTemplate,
  defaultHeaderFormat,
  extractVariables,
  finalizeTemplateName,
  getHeaderFormats,
  getTemplateModelDefinition,
  insertVariableAtSelection,
  interpolatePreview,
  isValidNamedVariable,
  nextPositionalVariable,
  sanitizeTemplateName,
  sanitizeExamples,
  sortTemplatesByMostRecent,
  templateToDraft,
  validateStep,
} from '../templateModel';

describe('meta template model', () => {
  it('uses icons available in the dashboard icon set', () => {
    expect(getTemplateModelDefinition('catalog').icon).toBe(
      'i-lucide-briefcase-business'
    );
    expect(getTemplateModelDefinition('order_status').icon).toBe(
      'i-lucide-circle-check-big'
    );
    expect(getTemplateModelDefinition('call_permission_request').icon).toBe(
      'i-lucide-phone'
    );
  });

  it('exposes only the formats supported by each Meta category', () => {
    expect(CATEGORY_MODELS).toEqual({
      MARKETING: [
        'standard',
        'catalog',
        'order_details',
        'call_permission_request',
      ],
      UTILITY: [
        'standard',
        'order_details',
        'order_status',
        'call_permission_request',
      ],
      AUTHENTICATION: ['authentication'],
    });
    expect(getHeaderFormats('catalog')).toEqual(['NONE']);
    expect(getHeaderFormats('order_details')).toEqual([
      'NONE',
      'IMAGE',
      'DOCUMENT',
    ]);
    expect(defaultHeaderFormat('catalog')).toBe('NONE');
    expect(defaultHeaderFormat('order_details')).toBe('NONE');
  });

  it('extracts and previews named and numbered variables', () => {
    expect(
      extractVariables('Olá {{cliente}}, fatura {{vencimento}}', 'named')
    ).toEqual(['cliente', 'vencimento']);
    expect(extractVariables('Olá {{1}}, fatura {{2}}', 'positional')).toEqual([
      '1',
      '2',
    ]);
    expect(
      interpolatePreview('Olá {{cliente}}', { cliente: 'Maria' }, 'named')
    ).toBe('Olá Maria');
  });

  it('inserts variables at the selected text position', () => {
    expect(
      insertVariableAtSelection({
        text: 'Olá cliente',
        variable: 'nome_cliente',
        selectionStart: 4,
        selectionEnd: 11,
      })
    ).toEqual({
      text: 'Olá {{nome_cliente}}',
      cursor: 20,
    });
    expect(nextPositionalVariable('Olá {{1}}, pedido {{3}}')).toBe('4');
    expect(isValidNamedVariable('nome_cliente')).toBe(true);
    expect(isValidNamedVariable('Nome do cliente')).toBe(false);
  });

  it('normalizes template names to the format accepted by Meta', () => {
    expect(sanitizeTemplateName(' Cobrança @ Julho/2026! ')).toBe(
      'cobranca_julho_2026_'
    );
    expect(finalizeTemplateName(' Cobrança @ Julho/2026! ')).toBe(
      'cobranca_julho_2026'
    );
    expect(sanitizeTemplateName('___Modelo___Com espaços')).toBe(
      'modelo_com_espacos'
    );
  });

  it('converts variable formats without losing section examples', () => {
    const draft = createEmptyTemplate();
    draft.header.format = 'TEXT';
    draft.header.text = 'Olá {{cliente}}';
    draft.header.examples = { cliente: 'Maria' };
    draft.body.text = 'A fatura vence em {{vencimento}}.';
    draft.body.examples = { vencimento: '10/08/2026' };

    convertTemplateVariableFormat(draft, 'positional');

    expect(draft).toMatchObject({
      parameter_format: 'positional',
      header: {
        text: 'Olá {{1}}',
        examples: { 1: 'Maria' },
      },
      body: {
        text: 'A fatura vence em {{1}}.',
        examples: { 1: '10/08/2026' },
      },
    });

    convertTemplateVariableFormat(draft, 'named');

    expect(draft).toMatchObject({
      parameter_format: 'named',
      header: {
        text: 'Olá {{variable_1}}',
        examples: { variable_1: 'Maria' },
      },
      body: {
        text: 'A fatura vence em {{variable_1}}.',
        examples: { variable_1: '10/08/2026' },
      },
    });
  });

  it('normalizes Meta casing when converting a template for editing', () => {
    const draft = templateToDraft({
      id: 'template-1',
      name: 'aviso',
      language: 'pt_BR',
      category: 'utility',
      parameter_format: 'NAMED',
      components: [
        {
          type: 'body',
          text: 'Olá {{cliente}}',
          example: {
            body_text_named_params: [
              { param_name: 'cliente', example: 'Maria' },
            ],
          },
        },
        {
          type: 'buttons',
          buttons: [{ type: 'url', text: 'Abrir', url: 'https://example.com' }],
        },
      ],
    });

    expect(draft).toMatchObject({
      category: 'UTILITY',
      parameter_format: 'named',
      body: {
        text: 'Olá {{cliente}}',
        examples: { cliente: 'Maria' },
      },
      buttons: [{ type: 'URL', text: 'Abrir' }],
    });
  });

  it.each([
    [
      'catalog',
      {
        category: 'MARKETING',
        components: [
          { type: 'BODY', text: 'Conheça nossos produtos' },
          {
            type: 'BUTTONS',
            buttons: [{ type: 'CATALOG', text: 'Ver catálogo' }],
          },
        ],
      },
    ],
    [
      'order_details',
      {
        category: 'UTILITY',
        display_format: 'ORDER_DETAILS',
        components: [
          { type: 'BODY', text: 'Confira os detalhes' },
          {
            type: 'BUTTONS',
            buttons: [{ type: 'ORDER_DETAILS', text: 'Copiar Pix' }],
          },
        ],
      },
    ],
    [
      'order_status',
      {
        category: 'UTILITY',
        sub_category: 'ORDER_STATUS',
        components: [{ type: 'BODY', text: 'Seu pedido foi enviado' }],
      },
    ],
    [
      'call_permission_request',
      {
        category: 'MARKETING',
        components: [
          { type: 'BODY', text: 'Podemos ligar para você?' },
          { type: 'CALL_PERMISSION_REQUEST' },
        ],
      },
    ],
  ])('detects the %s special format when editing', (model, template) => {
    const draft = templateToDraft({
      id: `template-${model}`,
      name: `modelo_${model}`,
      language: 'pt_BR',
      ...template,
    });

    expect(draft.model).toBe(model);
  });

  it('keeps the fixed Meta action label when editing special formats', () => {
    const catalog = templateToDraft({
      category: 'MARKETING',
      components: [
        { type: 'BODY', text: 'Produtos' },
        {
          type: 'BUTTONS',
          buttons: [{ type: 'CATALOG', text: 'Abrir catálogo' }],
        },
      ],
    });

    expect(catalog.special.button_text).toBe('Abrir catálogo');
    expect(catalog.buttons).toEqual([]);
  });

  it('keeps only examples that still exist in the message', () => {
    const draft = createEmptyTemplate();
    draft.body.text = 'Olá {{cliente}}';
    draft.body.examples = { cliente: 'Maria', removida: 'Valor antigo' };

    sanitizeExamples(draft);

    expect(draft.body.examples).toEqual({ cliente: 'Maria' });
  });

  it('orders templates from the most recent date and leaves undated items last', () => {
    const templates = [
      { id: 'old', name: 'Antigo', last_updated_time: '2026-04-14T20:22:31Z' },
      { id: 'undated', name: 'Sem data' },
      { id: 'new', name: 'Novo', last_updated_time: '2026-07-29T18:32:57Z' },
    ];

    expect(sortTemplatesByMostRecent(templates).map(item => item.id)).toEqual([
      'new',
      'old',
      'undated',
    ]);
    expect(templates.map(item => item.id)).toEqual(['old', 'undated', 'new']);
  });

  it('validates identity, sequential variables, examples and button targets', () => {
    const draft = createEmptyTemplate();
    draft.name = 'Nome inválido';
    expect(validateStep(draft, 1)).toHaveProperty('name');

    draft.name = 'modelo_valido';
    draft.parameter_format = 'positional';
    draft.body.text = 'Olá {{2}}';
    draft.body.examples = { 2: 'Maria' };
    draft.buttons = [{ type: 'URL', text: 'Abrir', url: '' }];

    expect(validateStep(draft, 2)).toMatchObject({
      body: true,
      buttons: true,
    });
  });

  it('validates special actions and rejects incompatible hidden controls', () => {
    const catalog = createEmptyTemplate();
    catalog.name = 'catalogo';
    catalog.category = 'MARKETING';
    catalog.model = 'catalog';
    catalog.header.format = 'NONE';
    catalog.body.text = 'Veja nossos produtos';

    expect(validateStep(catalog, 2)).toHaveProperty('specialAction');

    catalog.special.button_text = 'Ver catálogo';
    expect(validateStep(catalog, 2)).toEqual({});

    const orderDetails = createEmptyTemplate();
    orderDetails.model = 'order_details';
    orderDetails.header.format = 'NONE';
    orderDetails.body.text = 'Confira os dados do pedido';

    expect(validateStep(orderDetails, 2)).toEqual({});

    const callPermission = createEmptyTemplate();
    callPermission.model = 'call_permission_request';
    callPermission.body.text = 'Podemos ligar para você?';
    callPermission.buttons = [
      { type: 'QUICK_REPLY', text: 'Sim', url: '', phone_number: '' },
    ];

    expect(validateStep(callPermission, 2)).toHaveProperty('buttons');
  });
});
