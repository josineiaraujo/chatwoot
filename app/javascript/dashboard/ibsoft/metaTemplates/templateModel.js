export const HEADER_FORMATS = Object.freeze([
  'NONE',
  'TEXT',
  'IMAGE',
  'VIDEO',
  'DOCUMENT',
]);

export const TEMPLATE_MODEL_DEFINITIONS = Object.freeze({
  standard: {
    categories: ['MARKETING', 'UTILITY'],
    headerFormats: HEADER_FORMATS,
    genericButtons: true,
    icon: 'i-lucide-message-square-text',
  },
  catalog: {
    categories: ['MARKETING'],
    headerFormats: ['NONE'],
    genericButtons: false,
    fixedButtonType: 'CATALOG',
    fixedButtonTextEditable: true,
    icon: 'i-lucide-briefcase-business',
  },
  order_details: {
    categories: ['MARKETING', 'UTILITY'],
    headerFormats: ['NONE', 'IMAGE', 'DOCUMENT'],
    genericButtons: false,
    fixedButtonType: 'ORDER_DETAILS',
    icon: 'i-lucide-receipt-text',
  },
  order_status: {
    categories: ['UTILITY'],
    headerFormats: ['NONE'],
    genericButtons: false,
    icon: 'i-lucide-circle-check-big',
  },
  call_permission_request: {
    categories: ['MARKETING', 'UTILITY'],
    headerFormats: HEADER_FORMATS,
    genericButtons: false,
    icon: 'i-lucide-phone',
  },
  authentication: {
    categories: ['AUTHENTICATION'],
    headerFormats: ['NONE'],
    genericButtons: false,
    icon: 'i-lucide-shield-check',
  },
});

export const CATEGORY_MODELS = Object.freeze(
  Object.fromEntries(
    ['MARKETING', 'UTILITY', 'AUTHENTICATION'].map(category => [
      category,
      Object.entries(TEMPLATE_MODEL_DEFINITIONS)
        .filter(([, definition]) => definition.categories.includes(category))
        .map(([model]) => model),
    ])
  )
);

export const getTemplateModelDefinition = model =>
  TEMPLATE_MODEL_DEFINITIONS[model] || TEMPLATE_MODEL_DEFINITIONS.standard;

export const getHeaderFormats = model =>
  getTemplateModelDefinition(model).headerFormats;

export const defaultHeaderFormat = model => {
  const formats = getHeaderFormats(model);
  return formats.includes('NONE') ? 'NONE' : formats[0];
};

const namedVariablePattern = /\{\{\s*([a-z][a-z0-9_]*)\s*\}\}/g;
const positionalVariablePattern = /\{\{\s*(\d+)\s*\}\}/g;
const namedVariableNamePattern = /^[a-z][a-z0-9_]*$/;

const templateTimestamp = template => {
  const timestamp = Date.parse(template?.last_updated_time || '');
  return Number.isNaN(timestamp) ? null : timestamp;
};

export const sortTemplatesByMostRecent = templates =>
  [...templates].sort((left, right) => {
    const leftTimestamp = templateTimestamp(left);
    const rightTimestamp = templateTimestamp(right);

    if (leftTimestamp === null && rightTimestamp === null) {
      return String(left?.name || '').localeCompare(String(right?.name || ''));
    }
    if (leftTimestamp === null) return 1;
    if (rightTimestamp === null) return -1;

    return (
      rightTimestamp - leftTimestamp ||
      String(left?.name || '').localeCompare(String(right?.name || ''))
    );
  });

export const createEmptyTemplate = () => ({
  name: '',
  language: 'pt_BR',
  category: 'UTILITY',
  model: 'standard',
  parameter_format: 'named',
  header: {
    format: 'NONE',
    text: '',
    media_handle: '',
    media_filename: '',
    media_preview_url: '',
    examples: {},
  },
  body: {
    text: '',
    examples: {},
  },
  footer: {
    text: '',
  },
  buttons: [],
  special: {
    button_text: '',
  },
  authentication: {
    add_security_recommendation: true,
    code_expiration_minutes: 10,
    otp_type: 'COPY_CODE',
  },
});

export const extractVariables = (text, parameterFormat) => {
  const pattern =
    parameterFormat === 'named'
      ? namedVariablePattern
      : positionalVariablePattern;
  return [...String(text || '').matchAll(pattern)].map(match => match[1]);
};

export const isValidNamedVariable = variable =>
  namedVariableNamePattern.test(String(variable || '').trim());

export const sanitizeTemplateName = value =>
  String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+/, '')
    .replace(/_+/g, '_')
    .slice(0, 512);

export const finalizeTemplateName = value =>
  sanitizeTemplateName(value).replace(/_+$/, '');

export const nextPositionalVariable = text => {
  const positions = extractVariables(text, 'positional')
    .map(Number)
    .filter(Number.isInteger);

  return String(Math.max(0, ...positions) + 1);
};

export const insertVariableAtSelection = ({
  text,
  variable,
  selectionStart,
  selectionEnd,
}) => {
  const currentText = String(text || '');
  const clampPosition = position => {
    if (!Number.isInteger(position)) return currentText.length;
    return Math.min(Math.max(position, 0), currentText.length);
  };
  const start = clampPosition(selectionStart);
  const end = Math.max(start, clampPosition(selectionEnd));
  const token = `{{${variable}}}`;

  return {
    text: `${currentText.slice(0, start)}${token}${currentText.slice(end)}`,
    cursor: start + token.length,
  };
};

export const convertTemplateVariableFormat = (draft, targetFormat) => {
  const sourceFormat = draft.parameter_format;
  if (
    sourceFormat === targetFormat ||
    !['named', 'positional'].includes(targetFormat)
  ) {
    return draft;
  }

  const pattern =
    sourceFormat === 'named' ? namedVariablePattern : positionalVariablePattern;

  ['header', 'body'].forEach(section => {
    const sourceExamples = draft[section].examples || {};
    const targetExamples = {};
    let position = 0;

    draft[section].text = String(draft[section].text || '').replace(
      pattern,
      (_match, sourceVariable) => {
        position += 1;
        const targetVariable =
          targetFormat === 'positional'
            ? String(position)
            : `variable_${sourceVariable}`;

        targetExamples[targetVariable] =
          sourceExamples[sourceVariable] ||
          targetExamples[targetVariable] ||
          '';

        return `{{${targetVariable}}}`;
      }
    );
    draft[section].examples = targetExamples;
  });

  draft.parameter_format = targetFormat;
  return draft;
};

const componentByType = (components, type) =>
  components.find(
    component => String(component.type || '').toUpperCase() === type
  ) || {};

const buttonByType = (component, type) =>
  (component.buttons || []).find(
    button => String(button.type || '').toUpperCase() === type
  ) || {};

const detectTemplateModel = (template, components) => {
  const category = String(template.category || '').toUpperCase();
  if (category === 'AUTHENTICATION') return 'authentication';
  if (componentByType(components, 'CALL_PERMISSION_REQUEST').type)
    return 'call_permission_request';

  const buttons = componentByType(components, 'BUTTONS');
  if (
    String(template.display_format || '').toUpperCase() === 'ORDER_DETAILS' ||
    buttonByType(buttons, 'ORDER_DETAILS').type
  )
    return 'order_details';
  if (buttonByType(buttons, 'CATALOG').type) return 'catalog';
  if (String(template.sub_category || '').toUpperCase() === 'ORDER_STATUS')
    return 'order_status';

  return 'standard';
};

const examplesFromComponent = (component, parameterFormat) => {
  const example = component.example || {};
  const type = String(component.type || '').toLowerCase();

  if (parameterFormat === 'named') {
    const values = example[`${type}_text_named_params`] || [];
    return Object.fromEntries(
      values.map(item => [item.param_name, item.example || ''])
    );
  }

  const values =
    type === 'body'
      ? example.body_text?.[0] || []
      : example[`${type}_text`] || [];
  return Object.fromEntries(values.map((value, index) => [index + 1, value]));
};

export const templateToDraft = template => {
  const draft = createEmptyTemplate();
  const components = template.components || [];
  const header = componentByType(components, 'HEADER');
  const body = componentByType(components, 'BODY');
  const footer = componentByType(components, 'FOOTER');
  const buttons = componentByType(components, 'BUTTONS');
  const category = String(template.category || 'UTILITY').toUpperCase();
  const parameterFormat = String(
    template.parameter_format || 'positional'
  ).toLowerCase();
  const model = detectTemplateModel(template, components);
  const catalogButton = buttonByType(buttons, 'CATALOG');
  const orderDetailsButton = buttonByType(buttons, 'ORDER_DETAILS');

  return {
    ...draft,
    name: template.name || '',
    language: template.language || 'pt_BR',
    category,
    model,
    parameter_format: parameterFormat,
    header: {
      ...draft.header,
      format: String(
        header.format || (header.text ? 'TEXT' : 'NONE')
      ).toUpperCase(),
      text: header.text || '',
      media_handle: header.example?.header_handle?.[0] || '',
      examples: examplesFromComponent(header, parameterFormat),
    },
    body: {
      text: body.text || '',
      examples: examplesFromComponent(body, parameterFormat),
    },
    footer: {
      text: footer.text || '',
    },
    buttons: (buttons.buttons || [])
      .filter(button =>
        ['QUICK_REPLY', 'URL', 'PHONE_NUMBER'].includes(
          String(button.type || '').toUpperCase()
        )
      )
      .map(button => ({
        type: String(button.type).toUpperCase(),
        text: button.text || '',
        url: button.url || '',
        phone_number: button.phone_number || '',
        example: button.example?.[0] || '',
      })),
    special: {
      button_text:
        catalogButton.text ||
        orderDetailsButton?.text ||
        draft.special.button_text,
    },
    authentication: {
      add_security_recommendation: body.add_security_recommendation !== false,
      code_expiration_minutes: footer.code_expiration_minutes || 10,
      otp_type: buttons.buttons?.[0]?.otp_type || 'COPY_CODE',
    },
  };
};

export const interpolatePreview = (text, examples, parameterFormat) => {
  const pattern =
    parameterFormat === 'named'
      ? namedVariablePattern
      : positionalVariablePattern;

  return String(text || '').replace(pattern, (_match, key) => {
    return examples?.[key] || `{{${key}}}`;
  });
};

export const sanitizeExamples = draft => {
  ['header', 'body'].forEach(section => {
    const validKeys = extractVariables(
      draft[section].text,
      draft.parameter_format
    );
    draft[section].examples = Object.fromEntries(
      validKeys.map(key => [key, draft[section].examples?.[key] || ''])
    );
  });
};

export const validateStep = (draft, step) => {
  const errors = {};
  const definition = getTemplateModelDefinition(draft.model);

  if (step === 1) {
    if (!/^[a-z0-9_]+$/.test(draft.name) || draft.name.length > 512)
      errors.name = true;
    if (!draft.language) errors.language = true;
    if (!CATEGORY_MODELS[draft.category]?.includes(draft.model))
      errors.model = true;
  }

  if (step === 2 && draft.model !== 'authentication') {
    if (!draft.body.text.trim() || draft.body.text.length > 1024)
      errors.body = true;
    if (draft.footer.text.length > 60) errors.footer = true;
    if (!definition.headerFormats.includes(draft.header.format))
      errors.header = true;
    if (
      ['IMAGE', 'VIDEO', 'DOCUMENT'].includes(draft.header.format) &&
      !draft.header.media_handle
    )
      errors.media = true;
    if (draft.header.format === 'TEXT' && !draft.header.text.trim())
      errors.header = true;
    if (draft.header.format === 'TEXT' && draft.header.text.length > 60)
      errors.header = true;

    ['header', 'body'].forEach(section => {
      const variables = extractVariables(
        draft[section].text,
        draft.parameter_format
      );
      if (
        variables.some(variable => !draft[section].examples?.[variable]?.trim())
      )
        errors[`${section}Examples`] = true;
      if (
        draft.parameter_format === 'positional' &&
        variables.some((variable, index) => variable !== String(index + 1))
      )
        errors[section] = true;
    });

    if (definition.genericButtons) {
      if (draft.buttons.length > 10) errors.buttons = true;
      if (
        draft.buttons.some(button => {
          if (!button.text.trim() || button.text.length > 25) return true;
          if (button.type === 'URL') return !button.url.trim();
          if (button.type === 'PHONE_NUMBER')
            return !button.phone_number.trim();
          return !['QUICK_REPLY', 'URL', 'PHONE_NUMBER'].includes(button.type);
        })
      )
        errors.buttons = true;
    } else if (draft.buttons.length) {
      errors.buttons = true;
    }

    if (
      definition.fixedButtonTextEditable &&
      (!draft.special.button_text.trim() ||
        draft.special.button_text.length > 25)
    )
      errors.specialAction = true;
  }

  if (
    step === 2 &&
    draft.model === 'authentication' &&
    (draft.authentication.code_expiration_minutes < 1 ||
      draft.authentication.code_expiration_minutes > 90)
  )
    errors.expiration = true;

  return errors;
};
