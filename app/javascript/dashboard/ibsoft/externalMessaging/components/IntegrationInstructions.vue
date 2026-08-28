<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import {
  buildPublicCurl,
  isIxcContract,
  isStandardContract,
} from '../integrationContracts';

const props = defineProps({
  publicEndpointUrl: {
    type: String,
    required: true,
  },
  publicCurlExample: {
    type: String,
    required: true,
  },
  orderUpdateEndpointUrl: {
    type: String,
    default: '',
  },
  orderUpdateCurlExample: {
    type: String,
    default: '',
  },
  integrationParameters: {
    type: Array,
    default: () => [],
  },
  instanceType: {
    type: String,
    default: 'standard',
  },
  authentication: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();
const activeScenarioId = ref('simple');

const fieldDescriptions = computed(() => ({
  TEMPLATE_NAME: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.TEMPLATE_NAME'
  ),
  TEMPLATE_LANGUAGE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.TEMPLATE_LANGUAGE'
  ),
  TEMPLATE_TYPE_SIMPLE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.TEMPLATE_TYPE_SIMPLE'
  ),
  BODY_NAMED: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.BODY_NAMED'
  ),
  BODY_POSITIONAL: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.BODY_POSITIONAL'
  ),
  HEADER_NAMED: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_NAMED'
  ),
  HEADER_POSITIONAL: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_POSITIONAL'
  ),
  HEADER_TEXT_ALIAS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_TEXT_ALIAS'
  ),
  HEADER_PARAMETER_NAME: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_PARAMETER_NAME'
  ),
  HEADER_DOCUMENT_TYPE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_DOCUMENT_TYPE'
  ),
  HEADER_LINK: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_LINK'
  ),
  HEADER_FILENAME: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_FILENAME'
  ),
  HEADER_APPEND_PDF: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_APPEND_PDF'
  ),
  HEADER_PDF_MODE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_PDF_MODE'
  ),
  HEADER_MEDIA_TYPE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.HEADER_MEDIA_TYPE'
  ),
  BUTTON_TYPE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.BUTTON_TYPE'
  ),
  BUTTON_VALUE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.BUTTON_VALUE'
  ),
  ORDER_TEMPLATE_TYPE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_TEMPLATE_TYPE'
  ),
  ORDER_REFERENCE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_REFERENCE'
  ),
  ORDER_TOTAL: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_TOTAL'
  ),
  ORDER_ITEM_NAME: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_ITEM_NAME'
  ),
  ORDER_PIX_CODE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_PIX_CODE'
  ),
  ORDER_PIX_MERCHANT: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_PIX_MERCHANT'
  ),
  ORDER_PIX_KEY: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_PIX_KEY'
  ),
  ORDER_PIX_KEY_TYPE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_PIX_KEY_TYPE'
  ),
  ORDER_BOLETO: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_BOLETO'
  ),
  ORDER_ITEMS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_ITEMS'
  ),
  ORDER_AMOUNTS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_AMOUNTS'
  ),
  ORDER_EXPIRATION: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_EXPIRATION'
  ),
  ORDER_OPTIONS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.ORDER_OPTIONS'
  ),
  UPDATE_REFERENCE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_REFERENCE'
  ),
  UPDATE_STATUS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_STATUS'
  ),
  UPDATE_ORDER_STATUS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_ORDER_STATUS'
  ),
  UPDATE_PAYMENT_STATUS: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_PAYMENT_STATUS'
  ),
  UPDATE_PAYMENT_TIMESTAMP: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_PAYMENT_TIMESTAMP'
  ),
  UPDATE_MESSAGE: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_MESSAGE'
  ),
  UPDATE_DESCRIPTION: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_DESCRIPTION'
  ),
  UPDATE_TOKEN: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_TOKEN'
  ),
  UPDATE_IXC_USER: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_IXC_USER'
  ),
  UPDATE_IXC_PASSWORD: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_IXC_PASSWORD'
  ),
  UPDATE_IXC_RECIPIENT: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_IXC_RECIPIENT'
  ),
  UPDATE_IXC_TEXT: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.FIELDS.UPDATE_IXC_TEXT'
  ),
}));

const field = (name, requirement, description) => ({
  name,
  requirement,
  description: fieldDescriptions.value[description],
});

const isIxc = computed(() => isIxcContract(props.instanceType));
const isStandard = computed(() => isStandardContract(props.instanceType));
const requestMethod = computed(() => {
  if (isStandard.value) {
    return t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.STANDARD_METHOD');
  }
  if (isIxc.value) {
    return t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.IXC_METHOD');
  }

  return t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.METHOD');
});
const requestDescription = computed(() => {
  if (isStandard.value) {
    return t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.STANDARD_DESCRIPTION'
    );
  }
  if (isIxc.value) {
    return t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.IXC_DESCRIPTION');
  }

  return t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.DESCRIPTION');
});
const publicCurl = fields =>
  buildPublicCurl({
    instanceType: props.instanceType,
    endpointUrl: props.publicEndpointUrl,
    messagePayload: fields.join('||'),
    recipient: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.RECIPIENT'),
    token: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.TOKEN_PLACEHOLDER'),
    username:
      props.authentication?.username ||
      t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.USERNAME_PLACEHOLDER'),
    password: t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PASSWORD_PLACEHOLDER'
    ),
  });

const orderUpdateAuthenticationRule = () => {
  if (isStandard.value) {
    return t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION_STANDARD'
    );
  }
  if (isIxc.value) {
    return t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION_IXC'
    );
  }

  return t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.AUTHENTICATION'
  );
};

const scenarios = computed(() => {
  const items = [
    {
      id: 'simple',
      icon: 'i-lucide-message-square-text',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.SIMPLE.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.SIMPLE.DESCRIPTION'
      ),
      fields: [
        field('template_name', 'required', 'TEMPLATE_NAME'),
        field('template_language', 'optional', 'TEMPLATE_LANGUAGE'),
        field('template_type', 'optional', 'TEMPLATE_TYPE_SIMPLE'),
        field('body.<nome>', 'conditional', 'BODY_NAMED'),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.SIMPLE.RULES.MATCH_TEMPLATE'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.SIMPLE.RULES.DEFAULTS'
        ),
      ],
      example: publicCurl([
        '[template_name]=aviso_simples',
        `[body.nome_cliente]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
        )}`,
      ]),
    },
    {
      id: 'variables',
      icon: 'i-lucide-braces',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.VARIABLES.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.VARIABLES.DESCRIPTION'
      ),
      fields: [
        field('header.variable.<nome>', 'conditional', 'HEADER_NAMED'),
        field('header.variable.1', 'conditional', 'HEADER_POSITIONAL'),
        field('header_text', 'conditional', 'HEADER_TEXT_ALIAS'),
        field('header.parameter_name', 'conditional', 'HEADER_PARAMETER_NAME'),
        field('body.<nome>', 'conditional', 'BODY_NAMED'),
        field('body.1, body.2, ...', 'conditional', 'BODY_POSITIONAL'),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.VARIABLES.RULES.HEADER_LIMIT'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.VARIABLES.RULES.BODY_MODE'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.VARIABLES.RULES.POSITION_SEQUENCE'
        ),
      ],
      example: publicCurl([
        '[template_name]=aviso_personalizado',
        `[header.variable.titulo]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.HEADER_TITLE'
        )}`,
        `[body.nome_cliente]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
        )}`,
        `[body.vencimento]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.DUE_DATE'
        )}`,
      ]),
    },
    {
      id: 'document',
      icon: 'i-lucide-file-text',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.DOCUMENT.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.DOCUMENT.DESCRIPTION'
      ),
      fields: [
        field('header_type=document', 'conditional', 'HEADER_DOCUMENT_TYPE'),
        field('header_link', 'required', 'HEADER_LINK'),
        field('header_filename', 'optional', 'HEADER_FILENAME'),
        field('header_append_pdf', 'optional', 'HEADER_APPEND_PDF'),
        field('header_pdf_mode', 'optional', 'HEADER_PDF_MODE'),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.DOCUMENT.RULES.HTTPS'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.DOCUMENT.RULES.TYPE_INFERENCE'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.DOCUMENT.RULES.PDF_OPTIONS'
        ),
      ],
      example: publicCurl([
        '[template_name]=fatura_pdf',
        '[header_type]=document',
        `[header_link]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.DOCUMENT_URL'
        )}`,
        '[header_append_pdf]=false',
        '[header_filename]=fatura-9388.pdf',
        `[body.nome_cliente]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
        )}`,
      ]),
    },
    {
      id: 'media',
      icon: 'i-lucide-image-play',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.MEDIA.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.MEDIA.DESCRIPTION'
      ),
      fields: [
        field('header_type=image|video', 'conditional', 'HEADER_MEDIA_TYPE'),
        field('header_link', 'required', 'HEADER_LINK'),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.MEDIA.RULES.FORMATS'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.MEDIA.RULES.HTTPS'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.MEDIA.RULES.NO_TEXT_VARIABLE'
        ),
      ],
      example: publicCurl([
        '[template_name]=aviso_com_imagem',
        '[header_type]=image',
        '[header_link]=https://cdn.exemplo.com/avisos/manutencao.png',
        `[body.nome_cliente]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
        )}`,
      ]),
    },
    {
      id: 'buttons',
      icon: 'i-lucide-mouse-pointer-click',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.BUTTONS.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.BUTTONS.DESCRIPTION'
      ),
      fields: [
        field('button.<índice>.type', 'required', 'BUTTON_TYPE'),
        field('button.<índice>.value', 'required', 'BUTTON_VALUE'),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.BUTTONS.RULES.INDEX'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.BUTTONS.RULES.TYPES'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.BUTTONS.RULES.MATCH_TEMPLATE'
        ),
      ],
      example: publicCurl([
        '[template_name]=fatura_com_link',
        `[body.nome_cliente]=${t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
        )}`,
        '[button.0.type]=url',
        '[button.0.value]=9388',
      ]),
    },
    {
      id: 'order',
      icon: 'i-lucide-receipt-text',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.DESCRIPTION'
      ),
      fields: [
        field('template_type=order', 'required', 'ORDER_TEMPLATE_TYPE'),
        field('order.reference_id', 'required', 'ORDER_REFERENCE'),
        field('order.total', 'required', 'ORDER_TOTAL'),
        field('order.item_name', 'optional', 'ORDER_ITEM_NAME'),
        field('order.payment.pix.code', 'conditional', 'ORDER_PIX_CODE'),
        field(
          'order.payment.pix.merchant_name',
          'conditional',
          'ORDER_PIX_MERCHANT'
        ),
        field('order.payment.pix.key', 'conditional', 'ORDER_PIX_KEY'),
        field(
          'order.payment.pix.key_type',
          'conditional',
          'ORDER_PIX_KEY_TYPE'
        ),
        field(
          'order.payment.boleto.digitable_line',
          'conditional',
          'ORDER_BOLETO'
        ),
        field('order.items.<índice>.*', 'optional', 'ORDER_ITEMS'),
        field(
          'order.subtotal|tax|shipping|discount',
          'optional',
          'ORDER_AMOUNTS'
        ),
        field('order.expiration_at', 'optional', 'ORDER_EXPIRATION'),
        field(
          'order.currency|goods_type|button_index',
          'optional',
          'ORDER_OPTIONS'
        ),
      ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.PAYMENT'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.PIX_AND_BOLETO'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.NO_SECOND_DYNAMIC_BUTTON'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.BOLETO_ONLY'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.PIX_DEFAULTS'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.TOTAL'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.ITEMS'
        ),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER.RULES.BUTTON_INDEX'
        ),
      ],
      example: props.publicCurlExample,
    },
  ];

  if (props.orderUpdateEndpointUrl) {
    items.push({
      id: 'order_update',
      icon: 'i-lucide-refresh-cw',
      title: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.TITLE'
      ),
      description: t(
        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.DESCRIPTION'
      ),
      fields: isIxc.value
        ? [
            field('user', 'required', 'UPDATE_IXC_USER'),
            field('pw', 'required', 'UPDATE_IXC_PASSWORD'),
            field('dest', 'required', 'UPDATE_IXC_RECIPIENT'),
            field('text', 'required', 'UPDATE_IXC_TEXT'),
            field('text: [fatura_id]', 'required', 'UPDATE_REFERENCE'),
            field('text: [status]', 'conditional', 'UPDATE_STATUS'),
            field('text: [order_status]', 'conditional', 'UPDATE_ORDER_STATUS'),
            field(
              'text: [payment_status]',
              'conditional',
              'UPDATE_PAYMENT_STATUS'
            ),
            field(
              'text: [payment_timestamp]',
              'optional',
              'UPDATE_PAYMENT_TIMESTAMP'
            ),
            field('text: [message]', 'optional', 'UPDATE_MESSAGE'),
            field('text: [description]', 'optional', 'UPDATE_DESCRIPTION'),
          ]
        : [
            field('fatura_id', 'required', 'UPDATE_REFERENCE'),
            field('status', 'conditional', 'UPDATE_STATUS'),
            field('order_status', 'conditional', 'UPDATE_ORDER_STATUS'),
            field('payment_status', 'conditional', 'UPDATE_PAYMENT_STATUS'),
            field('payment_timestamp', 'optional', 'UPDATE_PAYMENT_TIMESTAMP'),
            field('message', 'optional', 'UPDATE_MESSAGE'),
            field('description', 'optional', 'UPDATE_DESCRIPTION'),
            ...(!isStandard.value
              ? [field('token', 'required', 'UPDATE_TOKEN')]
              : []),
          ],
      rules: [
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.STATUS'
        ),
        orderUpdateAuthenticationRule(),
        t(
          'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS.ORDER_UPDATE.RULES.ACCEPTED'
        ),
      ],
      example: props.orderUpdateCurlExample,
    });
  }

  return items;
});

const activeScenario = computed(
  () =>
    scenarios.value.find(scenario => scenario.id === activeScenarioId.value) ||
    scenarios.value[0]
);

const requirementLabels = computed(() => ({
  required: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.REQUIREMENTS.REQUIRED'
  ),
  conditional: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.REQUIREMENTS.CONDITIONAL'
  ),
  optional: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.REQUIREMENTS.OPTIONAL'
  ),
}));

const requirementLabel = requirement =>
  requirementLabels.value[requirement] || requirementLabels.value.optional;

const requirementClass = requirement => {
  if (requirement === 'required') return 'bg-n-ruby-3 text-n-ruby-11';
  if (requirement === 'conditional') return 'bg-n-amber-3 text-n-amber-11';

  return 'bg-n-alpha-2 text-n-slate-11';
};

const copyText = async (value, successMessage) => {
  try {
    await navigator.clipboard.writeText(value);
    useAlert(successMessage);
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.COPY'));
  }
};
</script>

<template>
  <section class="overflow-hidden rounded-lg border border-n-weak">
    <header class="border-b border-n-weak p-4">
      <h2 class="mb-1 text-heading-2 text-n-slate-12">
        {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.TITLE') }}
      </h2>
      <p class="mb-0 text-body-small text-n-slate-11">
        {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.DESCRIPTION') }}
      </p>
    </header>

    <div class="grid gap-5 p-4">
      <section class="grid gap-3">
        <div>
          <h3 class="mb-1 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.TITLE') }}
          </h3>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{ requestDescription }}
          </p>
        </div>

        <div class="flex min-w-0 flex-col gap-2 sm:flex-row sm:items-center">
          <code
            class="w-fit rounded-md bg-n-alpha-2 px-2 py-1 text-label-small font-medium text-n-slate-12"
          >
            {{ requestMethod }}
          </code>
          <code
            class="min-w-0 flex-1 break-all rounded-md bg-n-solid-1 px-3 py-2 text-body-small text-n-slate-12"
          >
            {{ publicEndpointUrl }}
          </code>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.COPY_URL')"
            icon="i-lucide-copy"
            size="sm"
            color="slate"
            variant="faded"
            @click="
              copyText(
                publicEndpointUrl,
                t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.URL_COPIED')
              )
            "
          />
        </div>

        <div class="overflow-x-auto">
          <table class="w-full min-w-[620px] border-collapse text-left">
            <thead>
              <tr
                class="border-b border-n-weak text-label-small text-n-slate-11"
              >
                <th class="px-3 py-2">
                  {{
                    t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.NAME')
                  }}
                </th>
                <th class="px-3 py-2">
                  {{
                    t(
                      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.TABLE.REQUIREMENT'
                    )
                  }}
                </th>
                <th class="px-3 py-2">
                  {{
                    t(
                      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.PURPOSE'
                    )
                  }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="parameter in integrationParameters"
                :key="parameter.name"
                class="border-b border-n-weak last:border-b-0"
              >
                <td class="px-3 py-3">
                  <code class="text-label-small text-n-slate-12">
                    {{ parameter.name }}
                  </code>
                </td>
                <td class="px-3 py-3">
                  <span
                    class="rounded-md bg-n-ruby-3 px-2 py-1 text-label-small text-n-ruby-11"
                  >
                    {{ requirementLabel('required') }}
                  </span>
                </td>
                <td class="px-3 py-3 text-body-small text-n-slate-11">
                  {{ parameter.description }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div
          class="flex items-start gap-3 rounded-lg bg-n-alpha-2 p-3 text-n-slate-11"
        >
          <i class="i-lucide-clock-3 mt-0.5 size-4 shrink-0" />
          <p class="mb-0 text-body-small">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PROCESSING.ACCEPTED') }}
          </p>
        </div>

        <div
          v-if="isIxc"
          class="flex items-start gap-3 rounded-lg bg-n-amber-3 p-3 text-n-amber-11"
        >
          <i class="i-lucide-shield-alert mt-0.5 size-4 shrink-0" />
          <p class="mb-0 text-body-small">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.REQUEST.IXC_SECURITY')
            }}
          </p>
        </div>
      </section>

      <section class="grid gap-4 border-t border-n-weak pt-5">
        <div>
          <h3 class="mb-1 text-heading-3 text-n-slate-12">
            {{
              t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS_TITLE')
            }}
          </h3>
          <p class="mb-0 text-body-small text-n-slate-11">
            {{
              t(
                'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS_DESCRIPTION'
              )
            }}
          </p>
        </div>

        <nav
          class="grid grid-cols-2 gap-1 rounded-lg bg-n-alpha-2 p-1 sm:grid-cols-3 lg:grid-cols-4"
          :aria-label="
            t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.SCENARIOS_TITLE')
          "
        >
          <button
            v-for="scenario in scenarios"
            :key="scenario.id"
            type="button"
            class="flex min-h-11 min-w-0 items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
            :class="
              activeScenario.id === scenario.id
                ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
                : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12'
            "
            @click="activeScenarioId = scenario.id"
          >
            <i class="size-4 shrink-0" :class="scenario.icon" />
            <span class="truncate">{{ scenario.title }}</span>
          </button>
        </nav>

        <article class="grid min-w-0 gap-4">
          <div>
            <h4 class="mb-1 text-heading-3 text-n-slate-12">
              {{ activeScenario.title }}
            </h4>
            <p class="mb-0 text-body-small text-n-slate-11">
              {{ activeScenario.description }}
            </p>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full min-w-[720px] border-collapse text-left">
              <thead>
                <tr
                  class="border-b border-n-weak text-label-small text-n-slate-11"
                >
                  <th class="px-3 py-2">
                    {{
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.TABLE.FIELD'
                      )
                    }}
                  </th>
                  <th class="px-3 py-2">
                    {{
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.TABLE.REQUIREMENT'
                      )
                    }}
                  </th>
                  <th class="px-3 py-2">
                    {{
                      t(
                        'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.TABLE.DESCRIPTION'
                      )
                    }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="scenarioField in activeScenario.fields"
                  :key="scenarioField.name"
                  class="border-b border-n-weak last:border-b-0"
                >
                  <td class="px-3 py-3 align-top">
                    <code class="text-label-small text-n-slate-12">
                      {{ scenarioField.name }}
                    </code>
                  </td>
                  <td class="px-3 py-3 align-top">
                    <span
                      class="whitespace-nowrap rounded-md px-2 py-1 text-label-small"
                      :class="requirementClass(scenarioField.requirement)"
                    >
                      {{ requirementLabel(scenarioField.requirement) }}
                    </span>
                  </td>
                  <td class="px-3 py-3 text-body-small text-n-slate-11">
                    {{ scenarioField.description }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="grid gap-2 border-t border-n-weak pt-4">
            <h5 class="mb-0 text-sm font-medium text-n-slate-12">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.RULES_TITLE') }}
            </h5>
            <ul
              class="mb-0 grid list-disc gap-1 ps-5 text-body-small text-n-slate-11"
            >
              <li v-for="rule in activeScenario.rules" :key="rule">
                {{ rule }}
              </li>
            </ul>
          </div>

          <div class="grid min-w-0 gap-2 border-t border-n-weak pt-4">
            <div class="flex items-center justify-between gap-3">
              <h5 class="mb-0 text-sm font-medium text-n-slate-12">
                {{
                  t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.GUIDE.EXAMPLE_TITLE')
                }}
              </h5>
              <Button
                :label="t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.COPY_CURL')"
                icon="i-lucide-copy"
                size="sm"
                color="slate"
                variant="faded"
                @click="
                  copyText(
                    activeScenario.example,
                    t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.CURL_COPIED')
                  )
                "
              />
            </div>
            <pre
              class="max-h-96 overflow-auto whitespace-pre-wrap break-words rounded-lg bg-n-solid-1 p-3 text-xs text-n-slate-12"
            ><code>{{ activeScenario.example }}</code></pre>
          </div>
        </article>
      </section>
    </div>
  </section>
</template>
