<script setup>
import { computed, nextTick, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAlert } from 'dashboard/composables';
import CredentialsDialog from '../components/CredentialsDialog.vue';
import InstanceCard from '../components/InstanceCard.vue';
import InstanceDetail from '../components/InstanceDetail.vue';
import InstanceEditorDialog from '../components/InstanceEditorDialog.vue';
import OrderDefaultsDialog from '../components/OrderDefaultsDialog.vue';
import {
  buildOrderUpdateCurl as buildContractOrderUpdateCurl,
  buildPublicCurl as buildContractCurl,
  isIxcContract,
  issuedCredentialsFrom,
} from '../integrationContracts';
import { findInstanceType, translatedInstanceTypes } from '../instanceTypes';
import externalMessagingAPI from '../api';

const { t } = useI18n();

const endpoints = ref([]);
const inboxes = ref([]);
const selectedEndpointId = ref(null);
const deliveries = ref([]);
const deliveryMeta = ref({ page: 1, per_page: 25, total: 0 });
const isFetching = ref(false);
const isFetchingDeliveries = ref(false);
const historyLoaded = ref(false);
const isSaving = ref(false);
const isSavingOrderDefaults = ref(false);
const isRotatingCredentials = ref(false);
const revealedCredentials = ref(null);
const revealedInstanceType = ref('');
const tokenDialogRef = ref(null);
const credentialsDialogRef = ref(null);
const editorDialogRef = ref(null);
const orderDefaultsDialogRef = ref(null);

const instanceTypes = computed(() => translatedInstanceTypes(t));
const selectedEndpoint = computed(() =>
  endpoints.value.find(endpoint => endpoint.id === selectedEndpointId.value)
);
const selectedTypeDefinition = computed(() => {
  const type = findInstanceType(selectedEndpoint.value?.instance_type);
  return {
    ...type,
    label: type.label(t),
    description: type.description(t),
  };
});
const typeDefinitionFor = endpoint => {
  const type = findInstanceType(endpoint.instance_type);
  return {
    ...type,
    label: type.label(t),
    description: type.description(t),
  };
};
const publicEndpointUrl = computed(() => {
  const origin = window.location?.origin || '';
  const publicPath = selectedEndpoint.value?.public_path;
  return publicPath ? `${origin}${publicPath}` : '';
});
const orderUpdateEndpointUrl = computed(() => {
  const origin = window.location?.origin || '';
  const publicPath = selectedEndpoint.value?.order_update_path;
  return publicPath ? `${origin}${publicPath}` : '';
});
const integrationParameters = computed(() => {
  const parameterNames = isIxcContract(selectedEndpoint.value?.instance_type)
    ? ['user', 'pw', 'dest', 'text']
    : ['msg', 'to', 'token'];
  const descriptions = {
    user: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.USER'),
    pw: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.PW'),
    dest: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.DEST'),
    text: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.TEXT'),
    msg: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.MSG'),
    to: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.TO'),
    token: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.PARAMETERS.TOKEN'),
  };

  return parameterNames.map(name => ({
    name,
    description: descriptions[name],
  }));
});
const messagePayloadExample = computed(() =>
  [
    `[template_name]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.TEMPLATE_NAME'
    )}`,
    '[template_type]=order',
    '[header_type]=document',
    `[header_link]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.DOCUMENT_URL'
    )}`,
    '[header_append_pdf]=false',
    `[body.nome_cliente]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.CUSTOMER_NAME'
    )}`,
    `[body.vencimento_fatura]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.DUE_DATE'
    )}`,
    `[order.reference_id]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.ORDER_REFERENCE'
    )}`,
    `[order.total]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.ORDER_TOTAL'
    )}`,
    `[order.item_name]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.ITEM_NAME'
    )}`,
    `[order.payment.pix.code]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PIX_CODE'
    )}`,
    `[order.payment.pix.merchant_name]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PIX_MERCHANT'
    )}`,
    `[order.payment.pix.key]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PIX_KEY'
    )}`,
    '[order.payment.pix.key_type]=CNPJ',
    `[order.payment.boleto.digitable_line]=${t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.BOLETO_LINE'
    )}`,
  ].join('||')
);
const exampleCredentials = computed(() => ({
  token: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.TOKEN_PLACEHOLDER'),
  username:
    selectedEndpoint.value?.authentication?.username ||
    t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.USERNAME_PLACEHOLDER'),
  password: t(
    'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.PASSWORD_PLACEHOLDER'
  ),
}));
const contractCurl = ({ instanceType, credentials }) =>
  buildContractCurl({
    instanceType,
    endpointUrl: publicEndpointUrl.value,
    messagePayload: messagePayloadExample.value,
    recipient: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.RECIPIENT'),
    ...credentials,
  });
const publicCurlExample = computed(() =>
  contractCurl({
    instanceType: selectedEndpoint.value?.instance_type,
    credentials: exampleCredentials.value,
  })
);
const orderUpdateCurlExample = computed(() =>
  buildContractOrderUpdateCurl({
    instanceType: selectedEndpoint.value?.instance_type,
    endpointUrl: orderUpdateEndpointUrl.value,
    reference: t(
      'IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.ORDER_REFERENCE'
    ),
    status: 'pago',
    recipient: t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.EXAMPLE.RECIPIENT'),
    ...exampleCredentials.value,
  })
);
const isRevealedIxc = computed(() => isIxcContract(revealedInstanceType.value));
const credentialDialogTitle = computed(() =>
  isRevealedIxc.value
    ? t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.IXC_TITLE')
    : t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.TOKEN_TITLE')
);
const credentialDialogDescription = computed(() =>
  isRevealedIxc.value
    ? t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.IXC_DESCRIPTION')
    : t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.TOKEN_DESCRIPTION')
);
const curlExample = computed(() =>
  contractCurl({
    instanceType: revealedInstanceType.value,
    credentials: {
      token: revealedCredentials.value?.token || '',
      username: revealedCredentials.value?.username || '',
      password: revealedCredentials.value?.password || '',
    },
  })
);

const fetchEndpoints = async () => {
  const { data } = await externalMessagingAPI.getEndpoints();
  endpoints.value = data.endpoints || [];
  inboxes.value = data.inboxes || [];

  if (
    selectedEndpointId.value &&
    !endpoints.value.some(endpoint => endpoint.id === selectedEndpointId.value)
  ) {
    selectedEndpointId.value = null;
  }
};

const fetchData = async () => {
  isFetching.value = true;
  try {
    await fetchEndpoints();
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.LOAD'));
  } finally {
    isFetching.value = false;
  }
};

const openCreate = () => editorDialogRef.value?.open();
const openEdit = endpoint => editorDialogRef.value?.open(endpoint);
const openOrderDefaults = endpoint =>
  orderDefaultsDialogRef.value?.open(endpoint);
const openCredentials = endpoint => credentialsDialogRef.value?.open(endpoint);

const openInstance = endpoint => {
  selectedEndpointId.value = endpoint.id;
  deliveries.value = [];
  deliveryMeta.value = { page: 1, per_page: 25, total: 0 };
  historyLoaded.value = false;
};

const closeInstance = () => {
  selectedEndpointId.value = null;
  deliveries.value = [];
  historyLoaded.value = false;
};

const showCredentials = async payload => {
  const credentials = issuedCredentialsFrom(payload);
  if (!credentials) return;

  revealedCredentials.value = credentials;
  revealedInstanceType.value =
    payload.instance_type || selectedEndpoint.value?.instance_type || '';
  await nextTick();
  tokenDialogRef.value?.open();
};

const clearCredentials = () => {
  revealedCredentials.value = null;
  revealedInstanceType.value = '';
};

const saveEndpoint = async ({ id, payload }) => {
  isSaving.value = true;
  try {
    const response = id
      ? await externalMessagingAPI.updateEndpoint(id, payload)
      : await externalMessagingAPI.createEndpoint(payload);

    editorDialogRef.value?.close();
    await fetchEndpoints();
    selectedEndpointId.value = response.data.id;
    historyLoaded.value = false;
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.SAVED'));
    await showCredentials(response.data);
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.SAVE'));
  } finally {
    isSaving.value = false;
  }
};

const saveOrderDefaults = async ({ id, payload }) => {
  isSavingOrderDefaults.value = true;
  try {
    await externalMessagingAPI.updateEndpoint(id, payload);
    orderDefaultsDialogRef.value?.close();
    await fetchEndpoints();
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ORDERS.SAVED'));
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.ORDER_DEFAULTS_SAVE'));
  } finally {
    isSavingOrderDefaults.value = false;
  }
};

const toggleEndpoint = async endpoint => {
  try {
    if (endpoint.active) {
      await externalMessagingAPI.deactivateEndpoint(endpoint.id);
    } else {
      await externalMessagingAPI.updateEndpoint(endpoint.id, { active: true });
    }
    await fetchEndpoints();
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.SAVE'));
  }
};

const rotateToken = async endpoint => {
  isRotatingCredentials.value = true;
  try {
    const { data } = await externalMessagingAPI.rotateToken(endpoint.id);
    credentialsDialogRef.value?.close();
    await showCredentials(data);
    try {
      await fetchEndpoints();
    } catch {
      useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.LOAD'));
    }
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.ROTATE'));
  } finally {
    isRotatingCredentials.value = false;
  }
};

const fetchDeliveries = async ({ status = '', page = 1, per_page = 25 }) => {
  if (!selectedEndpoint.value) return;

  isFetchingDeliveries.value = true;
  try {
    const params = {
      endpoint_id: selectedEndpoint.value.id,
      page,
      per_page,
    };
    if (status) params.status = status;

    const { data } = await externalMessagingAPI.getDeliveries(params);
    deliveries.value = data.deliveries || [];
    deliveryMeta.value = data.meta || deliveryMeta.value;
    historyLoaded.value = true;
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.DELIVERIES_LOAD'));
  } finally {
    isFetchingDeliveries.value = false;
  }
};

const copyText = async (value, successMessage) => {
  try {
    await navigator.clipboard.writeText(value);
    useAlert(successMessage);
  } catch {
    useAlert(t('IBSOFT_EXTERNAL_MESSAGING.ERRORS.COPY'));
  }
};

const copyCredential = (field, successMessage) =>
  copyText(revealedCredentials.value?.[field] || '', successMessage);

onMounted(fetchData);
</script>

<template>
  <section class="flex h-full min-w-0 flex-1 overflow-y-auto">
    <div class="mx-auto grid w-full max-w-7xl content-start gap-5 p-4 md:p-6">
      <div v-if="isFetching" class="grid min-h-80 place-content-center">
        <Spinner />
      </div>

      <InstanceDetail
        v-else-if="selectedEndpoint"
        :endpoint="selectedEndpoint"
        :type-definition="selectedTypeDefinition"
        :deliveries="deliveries"
        :delivery-meta="deliveryMeta"
        :is-fetching-deliveries="isFetchingDeliveries"
        :history-loaded="historyLoaded"
        :public-endpoint-url="publicEndpointUrl"
        :public-curl-example="publicCurlExample"
        :order-update-endpoint-url="orderUpdateEndpointUrl"
        :order-update-curl-example="orderUpdateCurlExample"
        :integration-parameters="integrationParameters"
        @back="closeInstance"
        @edit="openEdit"
        @credentials="openCredentials"
        @toggle="toggleEndpoint"
        @load-history="fetchDeliveries"
        @configure-orders="openOrderDefaults"
      />

      <template v-else>
        <header
          class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between"
        >
          <div>
            <h1 class="mb-1 text-heading-1 text-n-slate-12">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.TITLE') }}
            </h1>
            <p class="mb-0 max-w-3xl text-body-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.DESCRIPTION') }}
            </p>
          </div>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.NEW')"
            icon="i-lucide-plus"
            @click="openCreate"
          />
        </header>

        <div
          v-if="endpoints.length"
          class="grid gap-4 sm:grid-cols-2 2xl:grid-cols-3"
        >
          <InstanceCard
            v-for="endpoint in endpoints"
            :key="endpoint.id"
            :endpoint="endpoint"
            :type-definition="typeDefinitionFor(endpoint)"
            @view="openInstance"
            @edit="openEdit"
            @credentials="openCredentials"
            @toggle="toggleEndpoint"
          />
        </div>

        <div
          v-else
          class="grid min-h-64 place-content-center rounded-lg border border-dashed border-n-weak p-6 text-center"
        >
          <span
            class="mx-auto mb-3 grid size-11 place-content-center rounded-lg bg-n-alpha-2 text-n-slate-11"
          >
            <i class="i-lucide-plug-zap size-5" />
          </span>
          <h2 class="mb-1 text-heading-3 text-n-slate-12">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EMPTY_TITLE') }}
          </h2>
          <p class="mb-4 max-w-md text-body-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.EMPTY') }}
          </p>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.ENDPOINTS.NEW')"
            icon="i-lucide-plus"
            class="mx-auto"
            @click="openCreate"
          />
        </div>
      </template>
    </div>

    <InstanceEditorDialog
      ref="editorDialogRef"
      :inboxes="inboxes"
      :instance-types="instanceTypes"
      :is-saving="isSaving"
      @save="saveEndpoint"
    />

    <OrderDefaultsDialog
      ref="orderDefaultsDialogRef"
      :is-saving="isSavingOrderDefaults"
      @save="saveOrderDefaults"
    />

    <CredentialsDialog
      ref="credentialsDialogRef"
      :is-rotating="isRotatingCredentials"
      @rotate="rotateToken"
    />

    <Dialog
      ref="tokenDialogRef"
      width="2xl"
      overflow-y-auto
      :title="credentialDialogTitle"
      :description="credentialDialogDescription"
      :show-cancel-button="false"
      :confirm-button-label="t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.CLOSE')"
      @confirm="tokenDialogRef?.close()"
      @close="clearCredentials"
    >
      <div class="ibsoft-external-messaging-dialog-content grid gap-4">
        <div v-if="isRevealedIxc" class="grid gap-3 sm:grid-cols-2">
          <div class="grid min-w-0 gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.USERNAME') }}
            </span>
            <div class="grid gap-2">
              <code
                class="break-all rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
              >
                {{ revealedCredentials?.username }}
              </code>
              <Button
                :label="
                  t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.COPY_USERNAME')
                "
                icon="i-lucide-copy"
                color="slate"
                variant="faded"
                @click="
                  copyCredential(
                    'username',
                    t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.USERNAME_COPIED')
                  )
                "
              />
            </div>
          </div>

          <div class="grid min-w-0 gap-1">
            <span class="text-label-small text-n-slate-11">
              {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.PASSWORD') }}
            </span>
            <div class="grid gap-2">
              <code
                class="break-all rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
              >
                {{ revealedCredentials?.password }}
              </code>
              <Button
                :label="
                  t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.COPY_PASSWORD')
                "
                icon="i-lucide-copy"
                color="slate"
                variant="faded"
                @click="
                  copyCredential(
                    'password',
                    t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.PASSWORD_COPIED')
                  )
                "
              />
            </div>
          </div>
        </div>

        <div v-else class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.TOKEN') }}
          </span>
          <div class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto]">
            <code
              class="break-all rounded-lg border border-n-weak bg-n-solid-1 p-3 text-sm text-n-slate-12"
            >
              {{ revealedCredentials?.token }}
            </code>
            <Button
              :label="t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.COPY_TOKEN')"
              icon="i-lucide-copy"
              color="slate"
              variant="faded"
              @click="
                copyCredential(
                  'token',
                  t('IBSOFT_EXTERNAL_MESSAGING.CREDENTIALS.TOKEN_COPIED')
                )
              "
            />
          </div>
        </div>

        <div class="grid gap-1">
          <span class="text-label-small text-n-slate-11">
            {{ t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.TEST_EXAMPLE') }}
          </span>
          <pre
            class="max-h-80 overflow-auto whitespace-pre-wrap break-words rounded-lg border border-n-weak bg-n-solid-1 p-3 text-xs text-n-slate-12"
          ><code>{{ curlExample }}</code></pre>
          <Button
            :label="t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.COPY_CURL')"
            icon="i-lucide-copy"
            color="slate"
            variant="faded"
            @click="
              copyText(
                curlExample,
                t('IBSOFT_EXTERNAL_MESSAGING.INTEGRATION.CURL_COPIED')
              )
            "
          />
        </div>
      </div>
    </Dialog>
  </section>
</template>

<style scoped>
:global(dialog:has(.ibsoft-external-messaging-dialog-content)) {
  max-height: calc(100dvh - 6rem);
}
</style>
