# Gerenciamento de modelos da Meta

## Objetivo

Este modulo privado permite que administradores listem, filtrem, criem,
editem e excluam modelos do WhatsApp Business Cloud sem sair do ChatHub.

A Meta permanece como fonte de verdade. O modulo nao cria tabela propria nem
mantem uma copia paralela dos modelos no banco. O cache reutiliza os campos
nativos `message_templates` e `message_templates_last_updated` de
`Channel::Whatsapp`.

## Escopo atual

- canais `Channel::Whatsapp` com provider `whatsapp_cloud`;
- acesso exclusivo para administradores;
- catalogo com pesquisa, filtros, paginacao de 30 modelos e sincronizacao
  manual;
- ordenacao pela data de criacao/ultima atualizacao disponibilizada pela Meta,
  dos modelos mais recentes para os mais antigos;
- criacao e edicao em tres etapas: configuracao, mensagem e revisao;
- insercao contextual de variaveis no cursor, respeitando o formato nomeado ou
  numerado selecionado;
- exemplos de variaveis exibidos junto ao cabecalho ou mensagem a que
  pertencem, sem uma lista global desconectada do campo;
- conversao confirmada entre formatos de variaveis, preservando textos e
  exemplos de cada componente;
- previa responsiva, mantida a direita do formulario em telas medias e grandes;
- previa com anatomia visual propria para cada formato: mensagem padrao,
  catalogo, detalhes do pedido, status do pedido, permissao para ligacao e
  autenticacao;
- variaveis nomeadas e numeradas;
- categorias Marketing, Utilidade e Autenticacao;
- modelo padrao com cabecalho de texto, imagem, video ou documento;
- catalogo para Marketing, com a acao exclusiva `CATALOG`;
- detalhes do pedido para Marketing e Utilidade, com
  `display_format=ORDER_DETAILS`, cabecalho opcional de imagem ou documento e
  acao exclusiva `ORDER_DETAILS`;
- status do pedido para Utilidade, identificado por
  `sub_category=ORDER_STATUS`;
- solicitacao de permissao para ligacao em Marketing e Utilidade, com o
  componente exclusivo `CALL_PERMISSION_REQUEST`;
- botoes de resposta rapida, URL e telefone;
- modelo de autenticacao com codigo de uso unico;
- upload resumivel de amostras de midia diretamente para a Meta;
- exclusao com confirmacao.

A Graph API nao devolve uma data de criacao separada neste endpoint. Ela
devolve `last_updated_time`; em um modelo nunca editado, esse instante
corresponde a criacao. Modelos sem esse campo continuam visiveis e aparecem
depois dos modelos que possuem data valida.

## Estrutura backend

Controllers:

- `app/controllers/api/v1/accounts/ibsoft/meta_templates/base_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/meta_templates/templates_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/meta_templates/media_uploads_controller.rb`

Services:

- `app/services/ibsoft/meta_templates/client.rb`: cliente da Graph API,
  paginacao por cursor, autenticacao e normalizacao de erros.
- `app/services/ibsoft/meta_templates/catalog.rb`: cache por WABA dentro da
  mesma conta e invalidacao apos mutacoes.
- `app/services/ibsoft/meta_templates/template_payload.rb`: monta o contrato
  enviado para a Meta.
- `app/services/ibsoft/meta_templates/template_actions.rb`: monta botoes
  genericos e acoes exclusivas dos formatos especiais.
- `app/services/ibsoft/meta_templates/template_format.rb`: concentra a matriz
  de formatos, categorias, cabecalhos e acoes permitidos.
- `app/services/ibsoft/meta_templates/template_validator.rb`: valida o modelo
  antes de qualquer requisicao externa.
- `app/services/ibsoft/meta_templates/media_uploader.rb`: cria a sessao
  resumivel e transmite o arquivo em streaming, sem carregar o arquivo inteiro
  na memoria.

Traducoes backend:

- `config/locales/ibsoft_meta_templates.en.yml`
- `config/locales/ibsoft_meta_templates.pt_BR.yml`

## Rotas

Todas as rotas sao autenticadas, vinculadas a conta atual e restritas a
administradores:

```text
GET    /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/templates
POST   /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/templates
GET    /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/templates/:id
PATCH  /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/templates/:id
DELETE /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/templates/:id
POST   /api/v1/accounts/:account_id/ibsoft/meta_templates/inboxes/:inbox_id/media_uploads
```

O controller busca o canal somente dentro de `Current.account`, evitando
acesso cruzado entre contas.

## Estrutura frontend

- `app/javascript/dashboard/ibsoft/metaTemplates/api.js`
- `app/javascript/dashboard/ibsoft/metaTemplates/routes.js`
- `app/javascript/dashboard/ibsoft/metaTemplates/templateModel.js`
- `app/javascript/dashboard/ibsoft/metaTemplates/views/Index.vue`
- `app/javascript/dashboard/ibsoft/metaTemplates/components/`
- `app/javascript/dashboard/ibsoft/metaTemplates/specs/`

Traducoes:

- `app/javascript/dashboard/i18n/locale/en/ibsoftMetaTemplates.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftMetaTemplates.json`

O acesso ocorre pelo icone de modelos no card de um canal WhatsApp Business
Cloud, dentro de Configuracoes de canais e departamentos.

`templateModel.js` concentra o registro equivalente usado pela interface. Ele
tambem detecta o formato de modelos existentes pelos campos e componentes
devolvidos pela Meta, permitindo editar catalogos, detalhes/status de pedido e
solicitacoes de ligacao sem converte-los indevidamente para o formato padrao.
O texto de cada componente permanece como fonte de verdade das variaveis.
`TemplateVariableField.vue` apenas insere os tokens no cursor e apresenta os
exemplos derivados desse texto; nao existe registro paralelo de variaveis.

`WhatsAppTemplatePreview.vue` reproduz a hierarquia da mensagem recebida no
WhatsApp sem alterar o payload. O fundo, a bolha, os cabecalhos, resumos e
acoes usam apenas tokens de tema. O padrao visual fica no asset privado
`assets/whatsapp-preview-pattern.svg`; nenhum recurso remoto e carregado pela
previa.

## Contratos especiais da Meta

| Categoria | Formatos disponibilizados |
| --- | --- |
| Marketing | Padrao, Catalogo, Detalhes do pedido, Permissao para ligacao |
| Utilidade | Padrao, Detalhes do pedido, Status do pedido, Permissao para ligacao |
| Autenticacao | Codigo de autenticacao |

Os formatos especiais nao compartilham os botoes genericos do formato padrao.
O frontend oculta combinacoes invalidas e o backend repete a validacao antes de
qualquer chamada externa.

O nome do modelo e normalizado durante a digitacao para o contrato da Meta:
minusculas, sem acentos, somente letras, numeros e `_`, com limite de 512
caracteres. Separadores consecutivos viram um unico `_` e o separador final e
removido quando o campo perde o foco. O backend permanece estrito e rejeita
nomes invalidos enviados fora da interface.

Depois de uma criacao ou edicao bem-sucedida, o workspace e fechado antes da
sincronizacao da listagem. O componente nao agenda novas renderizacoes durante
o proprio desmonte, evitando concorrencia entre o `Teleport`, a troca de rota e
a atualizacao dos modelos retornados pela Meta.

No editor atual do WhatsApp Manager, `ORDER_DETAILS` oferece `Nenhum`, `Imagem`
e `Documento` como tipos de cabecalho. `Nenhum` e um estado interno do editor:
o payload enviado para a Meta simplesmente omite o componente `HEADER`.
O texto tecnico do botao `ORDER_DETAILS` tambem nao e configuravel no Builder.
O modulo nao exibe esse campo e envia internamente o valor fixo
`Copy Pix code`, ainda exigido pelo contrato da Graph API.

Referencias oficiais:

- [Visao geral de templates](https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/overview.md)
- [Utility templates](https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/utility-templates/utility-templates.md)
- [Catalog templates - colecao oficial da Meta](https://www.postman.com/meta/whatsapp-business-platform/request/4z2awhk/create-catalog-template)
- [Order details template](https://developers.facebook.com/documentation/business-messaging/whatsapp/payments/payments-br/orderdetailstemplate.md)
- [Template categorization](https://developers.facebook.com/documentation/business-messaging/whatsapp/templates/template-categorization.md)
- [WhatsApp Business Calling - permissoes de ligacao](https://developers.facebook.com/documentation/business-messaging/whatsapp/calling/user-call-permissions.md)

Os links terminados em `.md` retornam a documentacao oficial em Markdown e
devem ser preferidos nas proximas revisoes dos contratos da Graph API.

## Cache e escala

- A leitura consulta o cache nativo do canal por ate 15 minutos.
- A sincronizacao percorre a paginacao por cursor da Meta em lotes de 100.
- O limite defensivo e de 100 paginas por sincronizacao.
- Canais da mesma conta e do mesmo WABA recebem o mesmo catalogo em uma unica
  sincronizacao.
- Canais de outra conta nunca compartilham cache, mesmo que tenham um
  identificador de WABA igual.
- Filtros, ordenacao e paginacao sao executados no backend sobre o catalogo
  completo. A ordenacao acontece antes da paginacao e o frontend reforca a
  ordem decrescente dentro da pagina recebida.
- Uploads de midia sao transmitidos por streaming e nao sao persistidos pelo
  ChatHub.

## Banco de dados

Nenhuma migration ou tabela Ibsoft foi criada para este modulo.

Dependencias nativas reutilizadas:

- `Channel::Whatsapp#message_templates`;
- `Channel::Whatsapp#message_templates_last_updated`;
- `provider_config['api_key']`;
- `provider_config['business_account_id']`.

## Variaveis

Nativas:

- `WHATSAPP_CLOUD_BASE_URL`;
- `WHATSAPP_API_VERSION`;
- `WHATSAPP_APP_ID`, configurada pelo WhatsApp Embedded Signup e necessaria
  para criar sessoes de upload de amostras. O modulo a le por
  `GlobalConfigService`, reutilizando o valor de `installation_configs`.

Ibsoft opcionais:

- `IBSOFT_META_TEMPLATES_TIMEOUT_SECONDS`, default `20`, limitado entre 5 e
  60 segundos;
- `IBSOFT_META_TEMPLATES_UPLOAD_TIMEOUT_SECONDS`, default `60`, limitado entre
  10 e 180 segundos.

## Pontos de acoplamento

Ponto backend no core:

- `config/routes.rb`: registra o namespace privado da API.

Conectores frontend:

- `app/javascript/dashboard/ibsoft/chathubSettings/routes.js`: agrega as rotas
  privadas do modulo.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`:
  mostra o atalho apenas em canais compativeis e para administradores.
- `app/javascript/dashboard/i18n/locale/en/index.js`
- `app/javascript/dashboard/i18n/locale/pt_BR/index.js`

Nao existe regra do modulo em models, controllers, jobs ou componentes centrais
de conversas do Chatwoot.

## Testes

Backend:

```bash
bundle exec rspec spec/services/ibsoft/meta_templates \
  spec/requests/api/v1/accounts/ibsoft/meta_templates
```

Frontend:

```bash
pnpm exec vitest run \
  app/javascript/dashboard/ibsoft/metaTemplates/specs \
  app/javascript/dashboard/ibsoft/i18n/specs/translationCompiler.spec.js
```

Lint:

```bash
bundle exec rubocop \
  app/controllers/api/v1/accounts/ibsoft/meta_templates \
  app/services/ibsoft/meta_templates \
  spec/services/ibsoft/meta_templates \
  spec/requests/api/v1/accounts/ibsoft/meta_templates

pnpm exec eslint app/javascript/dashboard/ibsoft/metaTemplates
```

Os specs nao fazem mutacoes reais na Meta. Requisicoes externas sao simuladas.

## Cuidados ao atualizar upstream

1. Conferir se `config/routes.rb` preservou apenas o namespace privado.
2. Conferir os dois agregadores de locale.
3. Conferir o agregador privado de rotas das configuracoes ChatHub.
4. Validar se `Channel::Whatsapp` ainda possui os dois campos nativos usados
   pelo cache.
5. Comparar a versao da Graph API homologada pelo Chatwoot.
6. Rodar os testes backend, frontend e o compilador de traducoes.
7. Testar manualmente em tema claro e escuro com um canal WhatsApp Cloud.
