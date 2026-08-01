# Mapa de customizacoes Ibsoft

Este arquivo e o inventario raiz das customizacoes privadas aplicadas sobre o
Chatwoot. Antes de atualizar com `upstream/develop`, fazer rebase, resolver
conflitos ou preparar uma imagem de producao, leia este arquivo para garantir
que todos os pontos privados foram preservados.

Regra permanente: qualquer novo modulo, patch, arquivo Ibsoft, migracao,
traducao, ponto de acoplamento no core ou dependencia tecnica deve ser
registrado aqui no mesmo commit da mudanca.

Documento operacional de variaveis de ambiente:

- `IBSOFT_ENVIRONMENT_VARIABLES.md`: lista variaveis nativas e Ibsoft usadas
  em producao, motivo de existencia, valores recomendados e comandos de
  verificacao.
- `IBSOFT_ERP.md`: documenta a camada privada de integracoes ERP, banco,
  rotas, tela administrativa e pontos de acoplamento.
- `IBSOFT_MESSAGE_BROADCAST.md`: documenta a base privada de disparo de
  mensagens, buscas IXC, tabelas, selecao de telefones e testes.
- `IBSOFT_MESSAGE_SIGNATURE.md`: documenta a assinatura privada no cabecalho,
  configuracao por conta/canal, neutralizacao da assinatura nativa e testes.
- `IBSOFT_INSTAGRAM_INBOUND.md`: documenta a politica privada que controla
  quais interacoes do Instagram podem iniciar novas conversas.
- `IBSOFT_EXTERNAL_MESSAGING.md`: documenta endpoints autenticados para ERPs,
  envio direto pela Meta, processamento assincrono e acompanhamento de status.
- `IBSOFT_META_TEMPLATES.md`: documenta o gerenciamento privado de modelos
  WhatsApp Business Cloud, cache, uploads, rotas e pontos de acoplamento.

## Como usar antes de sincronizar com upstream

1. Atualize a branch alinhada ao Chatwoot oficial:
   `git switch develop`, `git fetch upstream`, `git merge --ff-only upstream/develop`.
2. Antes de aplicar o upstream nas branches privadas, revise todos os itens
   marcados como `backport temporario` neste documento. Confirme se a correcao
   oficial ja entrou em `upstream/develop` e remova qualquer implementacao
   duplicada.
3. Leia as secoes `Pontos de acoplamento no Chatwoot original` e
   `Arquivos sensiveis para conflito`.
4. Atualize/rebaseie as branches privadas sobre `develop`.
5. Resolva primeiro os pontos de acoplamento pequenos no core.
6. Depois valide os modulos isolados em `app/**/ibsoft` e
   `app/javascript/**/ibsoft`.
7. Rode migracoes, testes e lint proporcionais aos modulos afetados.
8. Verifique manualmente os fluxos visuais do dashboard antes de publicar.

## Principio de manutencao

- O codigo privado deve ficar em namespace/diretorio Ibsoft sempre que possivel.
- Arquivos originais do Chatwoot devem receber apenas pontos pequenos de
  conexao.
- Regra de negocio privada nao deve ficar em models, services ou componentes
  centrais do Chatwoot.
- Patches visuais devem preferir CSS/SCSS isolado e classes estaveis.
- Textos exibidos ao usuario devem ficar em traducoes Ibsoft.
- Este mapa deve apontar exatamente onde o core foi tocado.

## Modulos e patches privados

### Componentes frontend compartilhados Ibsoft

Objetivo:

- Reunir pequenos componentes visuais reutilizaveis entre modulos privados,
  mantendo o acoplamento fora dos componentes nativos do Chatwoot.

Arquivos privados:

- `app/javascript/dashboard/ibsoft/components/IbsoftSelect.vue`: wrapper para
  selects usados nas telas Ibsoft. Remove o caret nativo do navegador e usa
  icone do design system, evitando que o icone apareca cortado em telas com o
  tema personalizado.

Uso atual:

- Configuracoes globais ChatHub:
  `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`.
- Distribuicao de atendimentos:
  `app/javascript/dashboard/ibsoft/conversationDistribution/components/DistributionPolicyForm.vue`,
  `TeamDistributionSettingsModal.vue`,
  `views/SupervisorDashboard.vue` e `views/EventLogsDashboard.vue`.

Pontos de acoplamento no Chatwoot original:

- Nenhum. O componente fica em `dashboard/ibsoft` e e consumido apenas por
  telas privadas Ibsoft.

### 0. Configuracoes globais ChatHub

Documento detalhado: `IBSOFT_CHATHUB_SETTINGS.md`.

Objetivo:

- Centralizar configuracoes globais do ChatHub que nao pertencem a canal ou
  departamento especifico.
- Expor, dentro do menu ChatHub, uma visualizacao propria em cards para canais
  de comunicacao e atalhos integrados para as telas nativas de departamentos e
  conta, sem editar os componentes nativos.
- Manter o item `Configuracoes do ChatHub` no final do menu principal e usar
  essa tela como entrada operacional para conta, agentes, departamentos e
  canais de comunicacao.
- Controlar o modal pos-login dos agentes por percentual da fila total
  disponivel, com minimo obrigatorio e sem limite manual para o agente assumir
  mais atendimentos.
- Controlar a janela de estabilizacao pos-login para evitar concentrar muitas
  atribuicoes no primeiro agente que volta online.
- Conceder permissao privada `ibsoft_chathub_settings_manage` para usuarios nao
  administradores acessarem a tela.

Arquivos privados principais:

- `app/models/ibsoft/chathub_settings/`
- `app/services/ibsoft/chathub_settings/`
- `app/controllers/api/v1/accounts/ibsoft/chathub_settings/`
- `app/javascript/dashboard/ibsoft/chathubSettings/`
- `spec/**/ibsoft/chathub_settings/`

Banco de dados:

- `db/migrate/20260702110000_create_ibsoft_chathub_settings.rb`
- tabelas `ibsoft_chathub_settings` e
  `ibsoft_chathub_agent_presence_states`.
- `db/migrate/20260705004000_drop_legacy_ibsoft_access_tables.rb` remove a
  tabela legada `ibsoft_chathub_settings_managers`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/chathub_settings`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend da tela de configuracoes ChatHub.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona item
  de menu quando o usuario e admin ou possui
  `ibsoft_chathub_settings_manage`, posicionado no final do menu principal.
  Tambem oculta visualmente os itens nativos de configuracao `Conta`,
  `Agente`, `Times` (exibido como `Departamentos`), `Canais de comunicacao`,
  `Robos` e `Integracoes` do menu padrao. As rotas nativas continuam existindo
  e sao acessadas pela tela privada ChatHub quando o usuario possui permissao.
- `app/views/api/v1/models/_user.json.jbuilder`: expande permissoes via
  `Ibsoft::PermissionRegistry`.
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  declara imports assincronos para as secoes integradas de conta, canais,
  departamentos, robos e integracoes. O id tecnico continua `teams`, seguindo o
  contrato nativo do Chatwoot, mas a UI exibe `Departamentos`.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`:
  renderiza canais de comunicacao em cards usando stores e rotas nativas de
  canais, sem editar o componente original.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/AutomationHandoffPolicyModal.vue`:
  desativa silenciosamente `enable_auto_assignment` via store nativa
  `inboxes/updateInbox` quando um canal e aberto nas regras Ibsoft. Isso evita
  concorrencia entre a atribuicao automatica nativa do Chatwoot e as politicas
  privadas de distribuicao, sem criar endpoint ou persistencia extra. A tela
  mostra apenas um LED discreto de status, sem texto explicativo visivel.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`:
  oculta a secao nativa de atribuicao automatica na tela de colaboradores do
  canal. A secao original permanece no arquivo; o toque e apenas um ponto de
  bloqueio visual para evitar reativacao manual da logica nativa.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`:
  preserva a secao ativa via query `section`, evitando que o usuario volte para
  outra secao apos abrir configuracoes nativas de canal, departamento, robo,
  integracao ou conta.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos da tela.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/chathub_settings spec/services/ibsoft/chathub_settings spec/requests/api/v1/accounts/ibsoft/chathub_settings`
- `bundle exec rspec spec/services/ibsoft/conversation_distribution/agent_entry_assignment_policy_spec.rb spec/services/ibsoft/conversation_distribution/agent_assignment_preview_spec.rb spec/services/ibsoft/conversation_distribution/agent_assignment_claimer_spec.rb spec/services/ibsoft/conversation_distribution/assignment_executor_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/chathubSettings/specs/defaults.spec.js app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/chathubSettings`

### 0.0.1. Integracoes ERP

Documento detalhado: `IBSOFT_ERP.md`.

Objetivo:

- Configurar conexoes com ERPs externos dentro da area administrativa de
  configuracoes ChatHub.
- Suportar varios provedores, com apenas uma conexao ativa por conta.
- Testar conexoes sem escrita no ERP, usando listagem de clientes com limite
  de 1 registro por provedor.
- Preparar a base para modulos futuros, como mensagens em massa, dependerem de
  uma camada ERP comum e isolada.

Arquivos privados principais:

- `app/models/ibsoft/erp/connection.rb`
- `app/controllers/api/v1/accounts/ibsoft/erp/`
- `app/services/ibsoft/erp/`
- `app/javascript/dashboard/ibsoft/erp/`
- `spec/**/ibsoft/erp/`

Banco de dados:

- `db/migrate/20260707120000_create_ibsoft_erp_connections.rb`
- tabela `ibsoft_erp_connections`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/erp`, incluindo o endpoint privado
  `POST /connections/:id/test_connection`.
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  registra a secao `erp` no menu administrativo da tela ChatHub.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos da UI.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/erp/connection_spec.rb spec/requests/api/v1/accounts/ibsoft/erp/connections_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/erp/specs/providerConfig.spec.js app/javascript/dashboard/ibsoft/erp/specs/Index.spec.js app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js`

### 0.0.2. Disparo de mensagens

Documento detalhado: `IBSOFT_MESSAGE_BROADCAST.md`.

Objetivo:

- Criar a base privada para envio de mensagens em massa usando o ERP ativo da
  conta.
- Implementar a primeira camada completa de leitura IXC para selecao de
  destinatarios.
- Suportar filtros IXC de infraestrutura em concentradores, incluindo POPs,
  transmissores OLT, interface de transmissao, caixa FTTH e porta do
  transmissor.
- Manter grupos fixos, disparos e destinatarios em tabelas proprias sem
  armazenar payload bruto do ERP.
- Definir telefone principal e telefone de fallback de forma centralizada.
- Exibir tela propria com historico inicial e fluxo guiado por etapas para
  escolher origem, montar destinatarios, salvar grupos fixos e optar entre
  disparo imediato ou salvamento como rascunho.
- Paginar todas as correspondencias por snapshot normalizado no Redis, com
  isolamento por conta/conexao/filtros, TTL de 15 minutos e lotes IXC de 100
  clientes, sem persistir payload bruto.
- Construir o snapshot em job proprio com lock distribuido, armazenando os
  clientes minimos em blocos comprimidos de 250 registros.
- Permitir pesquisa global na lista encontrada sem nova consulta ao ERP.
- Exibir a lista final em tabela de 10 itens por pagina, com busca, filtro,
  edicao de telefones e remocao de destinatarios.
- Consultar templates WhatsApp Cloud diretamente pela API da Meta no canal
  selecionado, exibindo preview do conteudo e gerando o mapeamento de
  variaveis automaticamente.
- Proteger o envio contra concorrencia com transicoes atomicas no PostgreSQL:
  apenas uma requisicao enfileira o rascunho, apenas um worker executa o
  broadcast e apenas um worker adquire cada destinatario. O estado operacional
  `processing` nao exige migration porque a coluna `status` ja e textual.

Arquivos privados principais:

- `app/models/ibsoft/message_broadcast/`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/`
- `app/services/ibsoft/message_broadcast/`
- `app/services/ibsoft/erp/adapters/ixc/`
- `app/javascript/dashboard/ibsoft/messageBroadcast/`
- `spec/**/ibsoft/message_broadcast/`
- `spec/services/ibsoft/erp/adapters/ixc/`

Banco de dados:

- `db/migrate/20260707130000_create_ibsoft_message_broadcast.rb`
- `db/migrate/20260709190000_add_template_variable_values_to_ibsoft_message_broadcast_recipients.rb`
- tabelas `ibsoft_message_broadcast_groups`,
  `ibsoft_message_broadcast_group_members`,
  `ibsoft_message_broadcasts` e
  `ibsoft_message_broadcast_recipients`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API privadas de
  `/api/v1/accounts/:account_id/ibsoft/message_broadcast`, incluindo lookups
  IXC de estados, cidades, planos, POPs e transmissores, alem do endpoint
  privado `GET /templates` para sincronizar templates Meta do canal WhatsApp e
  `POST /broadcasts/:id/send_broadcast` para iniciar envio assincrono.
  Concentradores sao informados por ID numerico no filtro de PPPoE.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend privada `ibsoft_message_broadcast`.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona o
  item de menu `Disparo de mensagens` para administradores.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: textos da UI.

Validacao recomendada:

- `RAILS_ENV=test bundle exec rspec spec/services/ibsoft/message_broadcast spec/services/ibsoft/erp/adapters/ixc/customer_search_spec.rb spec/requests/api/v1/accounts/ibsoft/message_broadcast spec/models/ibsoft/message_broadcast`
- `./node_modules/.bin/vitest run app/javascript/dashboard/ibsoft/messageBroadcast/specs/Index.spec.js app/javascript/dashboard/ibsoft/messageBroadcast/specs/LookupSelects.spec.js --no-cache --no-coverage --logHeapUsage`

### 0.0.3. Assinatura de mensagens

Documento detalhado: `IBSOFT_MESSAGE_SIGNATURE.md`.

Objetivo:

- Adicionar o nome do agente em destaque no cabecalho de mensagens publicas
  enviadas por humanos.
- Preservar sem assinatura mensagens enviadas por integracoes externas com
  `api_access_token`.
- Permitir ativacao geral por conta e selecao dos canais de comunicacao.
- Substituir funcionalmente o rodape nativo sem apagar a coluna ou o codigo do
  Chatwoot.
- Operar sem tabela, migration, worker, Redis ou variavel de ambiente.

Arquivos privados principais:

- `app/services/ibsoft/message_signature/`
- `app/controllers/api/v1/accounts/ibsoft/message_signature/`
- `app/javascript/dashboard/ibsoft/messageSignature/`
- `config/initializers/ibsoft_message_signature.rb`
- `config/locales/ibsoft_message_signature.*.yml`
- `spec/**/ibsoft/message_signature/`

Persistencia:

- chave `ibsoft_message_signature` dentro de `accounts.settings`;
- nenhuma tabela ou migration adicional.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra a API privada de configuracao.
- `Messages::MessageBuilder`: recebe a extensao privada por initializer, sem
  edicao do builder.
- `Api::BaseController`: recebe por initializer o contexto privado que
  diferencia sessao do dashboard e token da API publica.
- `app/javascript/dashboard/store/modules/auth.js`: delega o getter da
  assinatura nativa ao neutralizador privado.
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  registra a tela administrativa.
- `app/javascript/dashboard/ibsoft/theme/_dark-overrides.scss`: oculta os dois
  controles nativos, preservando seu codigo.

Validacao recomendada:

- `bundle exec rspec spec/services/ibsoft/message_signature spec/requests/api/v1/accounts/ibsoft/message_signature`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/messageSignature/specs app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js app/javascript/dashboard/store/modules/specs/auth/getters.spec.js`

### 0.0.4. Politica de entrada do Instagram

Documento detalhado: `IBSOFT_INSTAGRAM_INBOUND.md`.

Objetivo:

- Controlar por canal se respostas e mencoes em Stories, compartilhamentos de
  Reels e Stories ou compartilhamentos de publicacoes podem iniciar uma nova
  conversa.
- Preservar todas essas interacoes quando ja existir conversa em andamento.
- Nao alterar mensagens diretas comuns nem qualquer canal diferente de
  Instagram.
- Nao interferir em comentarios publicos; eles permanecem integralmente sob o
  comportamento nativo do Chatwoot.
- Operar sem payload, log de eventos, worker ou Redis adicional.

Arquivos privados principais:

- `app/models/ibsoft/instagram_inbound/`
- `app/services/ibsoft/instagram_inbound/`
- `app/controllers/api/v1/accounts/ibsoft/instagram_inbound/`
- `app/javascript/dashboard/ibsoft/instagramInbound/`
- `config/initializers/ibsoft_instagram_inbound.rb`
- `config/locales/ibsoft_instagram_inbound.*.yml`
- `spec/**/ibsoft/instagram_inbound/`

Banco de dados:

- `db/migrate/20260723120000_create_ibsoft_instagram_inbound_policies.rb`
- tabela `ibsoft_instagram_inbound_policies`, com apenas tres booleanos
  funcionais e chave unica por conta/canal.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra a API privada.
- `Webhooks::InstagramEventsJob`: recebe extensao privada via initializer, sem
  edicao do job.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`:
  registra a aba condicional e monta o componente privado.
- `app/javascript/dashboard/i18n/locale/*/index.js`: registra os arquivos de
  traducao proprios.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/instagram_inbound spec/services/ibsoft/instagram_inbound spec/jobs/ibsoft/instagram_inbound spec/requests/api/v1/accounts/ibsoft/instagram_inbound`
- `pnpm test app/javascript/dashboard/ibsoft/instagramInbound/specs/SettingsPanel.spec.js`

### 0.0.5. API de envio de templates Meta

Documento detalhado: `IBSOFT_EXTERNAL_MESSAGING.md`.

Objetivo:

- receber solicitacoes de ERPs por endpoints autenticados vinculados a um
  canal WhatsApp Business Cloud;
- manter o contrato SGP Generico em
  `GET /chathub-sender/sgp/generico/` com `msg`, `to` e `token`;
- manter o contrato nativo IXC em `GET|POST /chathub-sender/ixc/`, com
  `user`, `pw`, `dest` e `text`;
- atualizar ordens e pagamentos pelos contratos compartilhados de familia
  `GET|POST /chathub-sender/sgp/pedido/` e
  `GET|POST /chathub-sender/ixc/pedido/`, processados de forma assincrona e
  serializados por ordem; a rota IXC preserva o envelope obrigatorio `user`,
  `pw`, `dest` e `text`, com os campos da ordem dentro de `text`;
- interpretar o formato `[campo]=valor||[outro]=valor`, validando variaveis e
  montando internamente os componentes aceitos pela Meta;
- enviar templates diretamente pela Meta, sem criar conversa ou mensagem no
  Chatwoot;
- processar com Sidekiq, persistencia duravel, idempotencia e limite
  distribuido por canal;
- acompanhar aceite, entrega, leitura e falha por webhook.
- apresentar instancias em catalogo administrativo, com tipo, configuracao,
  instrucoes e historico isolados;
- configurar defaults PIX por instancia, com prioridade para valores enviados
  pelo ERP e chave separada do JSON operacional;
- suportar novos tipos por registro de parser, autenticacao e contrato; os
  tipos atuais sao `sgp_generic` (**SGP Generico**) e `ixc` (**IXC**).

Arquivos privados principais:

- `app/models/ibsoft/external_messaging/`;
- `app/services/ibsoft/external_messaging/`;
- `app/jobs/ibsoft/external_messaging/`;
- `app/controllers/api/v1/ibsoft/external_messaging/`;
- `app/controllers/api/v1/accounts/ibsoft/external_messaging/`;
- `app/javascript/dashboard/ibsoft/externalMessaging/`;
- `app/javascript/dashboard/ibsoft/assets/images/logo/sgp/`;
- `app/javascript/dashboard/ibsoft/assets/images/logo/ixc/`;
- `spec/**/ibsoft/external_messaging/`.

Banco:

- `db/migrate/20260727090000_create_ibsoft_external_messaging.rb`;
- `db/migrate/20260727213000_add_instance_type_to_ibsoft_external_message_endpoints.rb`;
- `db/migrate/20260728100000_create_ibsoft_external_message_orders.rb`;
- `db/migrate/20260729100000_add_order_pix_defaults_to_ibsoft_external_messaging.rb`;
- tabelas `ibsoft_external_message_endpoints`,
  `ibsoft_external_message_deliveries`, `ibsoft_external_message_orders` e
  `ibsoft_external_message_order_updates`.

Pontos de acoplamento:

- `config/routes.rb`;
- `config/schedule.yml`;
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`;
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`;
- indexes i18n `en` e `pt_BR`;
- `db/schema.rb`.

O IXC reutiliza as tabelas existentes; nao exige migration propria e nao
armazena `user`, `pw` ou o envelope bruto. Nenhum model de conversa/mensagem ou
service nativo de envio foi alterado.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/external_messaging spec/services/ibsoft/external_messaging spec/jobs/ibsoft/external_messaging spec/requests/api/v1/ibsoft/external_messaging spec/requests/api/v1/accounts/ibsoft/external_messaging`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/externalMessaging/specs --no-coverage`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/externalMessaging`

### 0.1. Perfis e permissoes Ibsoft

Objetivo:

- Reproduzir funcionalmente o comportamento de perfis personalizados sem
  copiar ou depender do modulo Enterprise `custom_roles`.
- Manter perfis nomeados por conta, cada um com lista de permissoes, e permitir
  vincular um perfil a cada agente.
- Permitir que um futuro ambiente sem Enterprise continue controlando acesso a
  conversas, relatorios, contatos, base de conhecimento e telas privadas
  ChatHub.

Arquivos privados principais:

- `app/models/ibsoft/access_control/`
- `app/services/ibsoft/access_control/`
- `app/controllers/api/v1/accounts/ibsoft/access_control/`
- `app/javascript/dashboard/ibsoft/accessControl/`
- `spec/**/ibsoft/access_control/`

Banco de dados:

- `db/migrate/20260704100000_create_ibsoft_access_control.rb`
- tabela `ibsoft_access_control_roles`: perfis por conta, nome, descricao e
  array de permissoes.
- tabela `ibsoft_access_control_role_assignments`: vinculo unico de perfil por
  agente dentro da conta.

Comportamento:

- A tela user-facing chama o modulo de `Perfis e permissoes`.
- A tela principal lista apenas perfis, permissoes, contagem de agentes e acoes
  de perfil. O gerenciamento de agentes vinculados abre em modal contextual do
  perfil selecionado.
- Remover um agente no modal deixa o usuario sem perfil. Adicionar um agente ao
  perfil move automaticamente o usuario do perfil anterior, pois o vinculo e
  unico por agente dentro da conta.
- O namespace tecnico e `Ibsoft::AccessControl`.
- O catalogo de permissoes fica em
  `Ibsoft::AccessControl::PermissionCatalog`.
- O resolver de permissoes fica em
  `Ibsoft::AccessControl::PermissionResolver` e injeta as permissoes do perfil
  via `Ibsoft::PermissionRegistry`.
- Um agente com perfil Ibsoft recebe os marcadores `ibsoft_access_role` e
  `custom_role` no payload de permissoes para manter compatibilidade com
  filtros e rotas do dashboard que ja reconhecem perfis customizados.
- O modulo nao usa `custom_roles`, `custom_role_id` nem classes dentro de
  `enterprise/`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/access_control`.
- `config/initializers/ibsoft_access_control_policy_extensions.rb`: registra
  extensoes pequenas para policies e services nativos que precisam respeitar
  perfis Ibsoft:
  `ConversationPolicy`, `ContactPolicy`, `ReportPolicy`, `PortalPolicy`,
  `ArticlePolicy`, `CategoryPolicy`,
  `Conversations::PermissionFilterService` e
  `Conversations::UnreadCounts::Counter`.
- `app/services/ibsoft/permission_registry.rb`: adiciona
  `Ibsoft::AccessControl::PermissionResolver` como provider.
- `app/services/ibsoft/conversation_distribution/supervisor_permission.rb`:
  aceita a permissao `ibsoft_conversation_distribution_supervise` quando vier
  de perfil Ibsoft.
- `app/services/ibsoft/chathub_settings/permission.rb`: aceita a permissao
  `ibsoft_chathub_settings_manage` quando vier de perfil Ibsoft.
- `app/javascript/dashboard/helper/permissionsHelper.js`: trata
  `ibsoft_access_role` como perfil customizado no filtro visual de conversas.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`: adiciona a
  secao administrativa `Perfis e permissoes`.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: textos da UI.
- `db/schema.rb`: atualizado pela migration.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/access_control spec/services/ibsoft/access_control spec/requests/api/v1/accounts/ibsoft/access_control`
- `bundle exec rspec spec/services/ibsoft/conversation_distribution/supervisor_permission_spec.rb spec/services/ibsoft/chathub_settings/permission_spec.rb`
- `bundle exec rubocop app/models/ibsoft/access_control app/services/ibsoft/access_control app/controllers/api/v1/accounts/ibsoft/access_control config/initializers/ibsoft_access_control_policy_extensions.rb`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/accessControl app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue app/javascript/dashboard/helper/permissionsHelper.js`

### 0.2. Provisionamento de agentes Ibsoft

Objetivo:

- Criar agentes pelo fluxo operacional do ChatHub sem depender do e-mail de
  confirmacao do Devise.
- Continuar usando as tabelas nativas `users` e `account_users`, para preservar
  compatibilidade com conversas, times, canais, presenca online, relatorios e
  permissoes do Chatwoot.
- Gerar uma senha temporaria forte e exibi-la apenas uma vez na resposta de
  criacao, sem persistir senha em texto puro.
- Permitir gerar nova senha temporaria para agentes existentes dentro do modal
  de edicao, exibindo a senha apenas na resposta da acao.
- Permitir foto de perfil no cadastro e na edicao de agentes, com crop circular,
  zoom e deslocamento manual da imagem antes do envio.
- Permitir editar nome e e-mail do agente pelo endpoint privado, mantendo o
  `uid` sincronizado quando o provider for `email` e pulando a reconfirmacao
  administrativa para preservar o fluxo operacional sem e-mail de confirmacao.
- Exibir a disponibilidade atual do agente e permitir alterar manualmente entre
  online, ocupado e offline usando `account_users.availability` nativo do
  Chatwoot, preservando a politica nativa de offline automatico.
- Permitir definir, no cadastro e na edicao do agente, se o ChatHub deve marcar
  o agente como offline automaticamente quando nao houver presenca ativa no
  painel.

Arquivos privados principais:

- `app/services/ibsoft/agent_provisioning/create_agent.rb`
- `app/services/ibsoft/agent_provisioning/avatar_attacher.rb`
- `app/services/ibsoft/agent_provisioning/availability_normalizer.rb`
- `app/services/ibsoft/agent_provisioning/temporary_password_generator.rb`
- `app/services/ibsoft/user_defaults/notification_preferences.rb`
- `app/controllers/api/v1/accounts/ibsoft/agent_provisioning/`
- `app/javascript/dashboard/ibsoft/agentProvisioning/`
- `config/locales/ibsoft_agent_provisioning.*.yml`
- `spec/**/ibsoft/agent_provisioning/`

Comportamento:

- O modulo fica disponivel em Configuracoes do ChatHub, secao `Agentes`, apenas
  para administradores da conta. A tela principal lista os agentes e o cadastro
  rapido abre em modal.
- A lista de agentes mostra o avatar nativo do usuario, usando foto quando
  existir e fallback por iniciais quando nao existir, com indicador de status
  nativo do Chatwoot.
- A alteracao manual de disponibilidade atualiza apenas o `availability` do
  `AccountUser`. O modulo nao altera `auto_offline`, permitindo que o Chatwoot
  continue exibindo o agente como offline quando nao houver presenca ativa.
- Para coerencia visual e operacional, quando `auto_offline=true` e o status
  efetivo fica offline por ausencia de presenca, o modulo normaliza o
  `availability` salvo para `offline`. Assim o select da tela de agentes e o
  indicador do avatar nao exibem estados conflitantes.
- Novos agentes nascem com `auto_offline=true`, salvo quando o operador
  desativa explicitamente essa opcao no cadastro. A edicao permite ligar ou
  desligar essa mesma opcao no `AccountUser` da conta.
- A senha temporaria gerada no cadastro aparece dentro do proprio modal de
  criacao. Ao fechar o modal, a senha sai do estado do frontend.
- O cadastro e a edicao usam endpoint privado Ibsoft para aceitar multipart com
  avatar, sem alterar o controller nativo de agentes. O anexo e salvo no
  `has_one_attached :avatar` nativo do `User`.
- A remocao do agente continua usando a API nativa de agentes do Chatwoot,
  preservando o contrato original de `users` e `account_users`.
- Ao remover um agente que possui perfil privado do ChatHub, o frontend remove
  primeiro o vinculo em `ibsoft_access_control_role_assignments` para evitar
  vinculo privado inconsistente apos a remocao nativa da conta.
- A criacao chama `skip_confirmation!` no usuario novo antes de salvar, portanto
  o agente nasce confirmado e pode autenticar com a senha temporaria.
- Novos vinculos de usuario com conta aplicam
  `Ibsoft::UserDefaults::NotificationPreferences`, que cria preferencias
  padrao com e-mail desligado, notificacoes de navegador ativadas apenas para
  atribuicao, mencao, nova mensagem atribuida e nova mensagem em conversa
  participante, alem de audio `assigned` com tom `magic`. O service usa nomes
  de flags suportados pela versao atual do Chatwoot, sem depender da ordem ou
  do valor numerico da bitmask.
- O campo user-facing de permissao chama-se `Perfil`. Ele combina os papeis
  nativos `Administrador` e `Agente` com os perfis criados na area
  `Perfis e permissoes`.
- Quando um perfil criado na area `Perfis e permissoes` e escolhido, o usuario
  e criado com `account_users.role = agent` e o modulo grava automaticamente o
  vinculo em `ibsoft_access_control_role_assignments` dentro da mesma transacao.
- O fluxo rejeita e-mails ja existentes. Isso evita a falsa expectativa de
  revelar uma senha que o sistema nao conhece. Para usuarios existentes, usar
  recuperacao de senha ou um fluxo futuro de vinculo.
- O fluxo rejeita contas SAML para nao criar atalho local de senha em contas que
  deveriam autenticar por SSO.
- A gestao de perfis e permissoes continua separada na secao
  `Perfis e permissoes`.

Pontos de acoplamento no Chatwoot original:

- `app/models/account_user.rb`: o callback nativo de criacao de
  `NotificationSetting` foi reduzido a uma delegacao para
  `Ibsoft::UserDefaults::NotificationPreferences`; a regra privada permanece no
  service Ibsoft.
- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/agent_provisioning/agents`, incluindo
  `create`, `update` e a action member `reset_temporary_password`.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`: adiciona a
  secao administrativa `Agentes` dentro da tela privada ChatHub.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: textos da UI.

Validacao recomendada:

- `bundle exec rspec spec/services/ibsoft/agent_provisioning spec/requests/api/v1/accounts/ibsoft/agent_provisioning`
- `bundle exec rspec spec/services/ibsoft/user_defaults/notification_preferences_spec.rb spec/models/account_user_spec.rb`
- `bundle exec rubocop app/services/ibsoft/agent_provisioning app/controllers/api/v1/accounts/ibsoft/agent_provisioning spec/services/ibsoft/agent_provisioning spec/requests/api/v1/accounts/ibsoft/agent_provisioning`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/agentProvisioning/specs/AgentProvisioningPanel.spec.js`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/agentProvisioning app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`

### 1. Distribuicao de atendimentos Ibsoft

Documento detalhado: `IBSOFT_CONVERSATION_DISTRIBUTION.md`.

Objetivo:

- Criar uma politica privada de distribuicao e redistribuicao de atendimentos
  humanos, separada do Assignment V2 como motor executor.
- Permitir configuracao padrao por canal de comunicacao e sobrescrita por time.
- Encaminhar automaticamente conversas que ficaram presas na automacao para um
  time humano configurado por canal.
- Preparar suporte a horarios de funcionamento por time, fallback, alerta de
  supervisor e auditoria de redistribuicoes.

Arquivos privados principais:

- `app/models/ibsoft/conversation_distribution/`
- `app/services/ibsoft/conversation_distribution/`
- `app/jobs/ibsoft/conversation_distribution/`
- `app/controllers/api/v1/accounts/ibsoft/conversation_distribution/`
- `app/javascript/dashboard/ibsoft/conversationDistribution/`
- `app/javascript/dashboard/ibsoft/conversationDistribution/helpers/assignmentAudioNotifications.js`
- `config/locales/ibsoft_conversation_distribution.*.yml`
- `spec/**/ibsoft/conversation_distribution/`

Banco de dados:

- `db/migrate/20260701090000_create_ibsoft_conversation_distribution.rb`
- tabelas `ibsoft_conversation_distribution_channel_policies`,
  `ibsoft_conversation_distribution_team_policies` e
  `ibsoft_conversation_distribution_event_logs`.
- `db/migrate/20260702123000_create_ibsoft_conversation_distribution_policies.rb`
- `db/migrate/20260703123000_add_ibsoft_distribution_event_log_performance_indexes.rb`
- `db/migrate/20260706120000_create_ibsoft_automation_handoff_policies.rb`
- tabela `ibsoft_conversation_distribution_policies`, catalogo de politicas
  nomeadas reutilizaveis. Canais e times devem vincular uma politica por
  `distribution_policy_id` em vez de copiar regras diretamente.
- tabela `ibsoft_conversation_distribution_automation_handoff_policies`,
  politica por canal para tirar conversas paradas da automacao e encaminhar
  para um time humano.
- `db/migrate/20260703120000_remove_legacy_ibsoft_distribution_link_config.rb`
  remove `enabled` e `config` das tabelas de vinculo por canal/time. A migration
  preserva configuracoes antigas convertendo cada vinculo legado em politica
  nomeada antes de derrubar as colunas.
- Politicas Ibsoft possuem capacidades equivalentes ao Assignment V2 para a
  operacao privada: ordem por rodizio/equilibrada, prioridade por maior espera
  ou criacao, limite opcional por rodada e limite de capacidade por agente. O
  limite pode operar por atendimentos abertos simultaneos ou por novas
  atribuicoes dentro de uma janela.
- O bloco `assignment_confirmation` permite enviar mensagem automatica
  opcional quando o motor Ibsoft atribui a conversa a um agente online. O envio
  e feito por `AssignmentConfirmationNotifier` como mensagem `template`, sem
  remetente humano, preservando a metrica de primeira resposta.
- `ActivityMessageNotifier` cria mensagens internas `activity` para registrar
  atribuicao automatica, aceite manual pelo agente no modal pos-login e
  redistribuicao automatica por timeout. Tambem registra o encaminhamento de
  automacoes paradas para times humanos. Os textos ficam em Rails i18n proprio
  do modulo.
- A indisponibilidade operacional e separada por motivo no bloco
  `unavailability`: `no_available_agent` controla acoes quando nao ha atendente
  disponivel dentro do horario, e `outside_business_hours` controla acoes fora
  do horario. O campo legado `unavailable` segue aceito e e normalizado para os
  dois motivos quando a politica ainda nao usa o novo formato.
- A tela de cadastro/edicao das politicas fica em Configuracoes do ChatHub.
  O fluxo deve seguir o Assignment V2: listar politicas em cards de largura
  total, editar em modal, remover pelo card e criar novas politicas apenas pelo
  botao de adicionar. Configuracoes de canal e time devem apenas selecionar o
  vinculo com uma politica existente.
- O modal `AutomationHandoffPolicyModal.vue`, aberto pelo card de canal em
  Configuracoes do ChatHub, usa abas para concentrar as regras operacionais do
  canal: vinculo da politica de distribuicao e politica de automacoes paradas.
  Ele nao altera a tela nativa de canais.
- `db/migrate/20260705004000_drop_legacy_ibsoft_access_tables.rb` remove a
  tabela legada `ibsoft_conversation_distribution_supervisors`. A permissao de
  supervisao agora e concedida por perfis e permissoes Ibsoft.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/conversation_distribution`.
- `config/schedule.yml`: registra o cron privado
  `ibsoft_conversation_distribution_watchdog_job`, inerte por flag.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`:
  teve o encaixe Ibsoft de distribuicao removido para que as regras privadas do
  canal fiquem apenas no modal de Configuracoes do ChatHub, reduzindo
  acoplamento com a tela nativa do Chatwoot.
- `app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue`: registra
  o botao de configuracao de distribuicao por time.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend do painel de supervisao Ibsoft.
- `app/javascript/dashboard/routes/dashboard/Dashboard.vue`: monta o prompt
  privado de assuncao de fila do agente quando o usuario fica online.
- `app/javascript/dashboard/helper/actionCable.js`: delega o evento nativo
  `assignee.changed` para helper privado Ibsoft que decide se deve tocar som
  para o usuario que recebeu a atribuicao ou redistribuicao.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: registra a
  Home do ChatHub no menu lateral. O acesso visual ao painel de supervisao fica
  dentro da Home e e exibido somente para administradores ou usuarios com
  permissao `ibsoft_conversation_distribution_supervise`.
- `app/javascript/dashboard/ibsoft/conversationDistribution/views/SupervisorDashboard.vue`:
  adiciona o retorno para `ibsoft_chathub_home` no cabecalho da supervisao.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: registram
  textos da UI do modulo.
- `app/views/api/v1/models/_user.json.jbuilder`: adiciona a permissao privada
  `ibsoft_conversation_distribution_supervise` ao payload de contas do usuario
  quando ele estiver registrado como supervisor Ibsoft.
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`:
  marca origem Ibsoft quando uma conversa e atribuida a time via API/UI.
- `app/javascript/dashboard/store/modules/conversations/actions.js`: delega as
  atribuicoes individuais de agente e departamento do dashboard ao endpoint
  privado `manual_assignment`, sincronizando o estado confirmado pelo backend
  por meio de `manualAssignmentStateSync.js`. Conversas que sairam da lista
  durante a requisicao nao recebem mutacoes tardias.
- `app/javascript/dashboard/routes/dashboard/conversation/ConversationAction.vue`,
  `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue`
  e `app/javascript/dashboard/composables/commands/useConversationHotKeys.js`:
  conectam os controles individuais ao fluxo privado e bloqueiam transferencias
  quando a conversa esta encerrada. No menu de contexto, agente e departamento
  foram consolidados em `Transferir atendimento`, com modais privados para
  escolher o agente ou a fila do departamento. Se ja houver agente humano
  responsavel, somente ele ou um administrador pode transferir; a regra e
  repetida no backend por `ManualTransferPermission`. Conversas atribuidas a
  bot permanecem transferiveis conforme `meta.assignee_type=AgentBot`.
- `app/javascript/dashboard/composables/chatlist/useBulkActions.js`: usa o
  fluxo privado apenas quando a acao veio do menu contextual de uma conversa;
  atribuicoes realmente em massa continuam nativas.
- `app/services/action_service.rb`: marca origem Ibsoft quando uma acao,
  automacao ou macro atribui a conversa a um time.

Estado atual:

- Incremento inicial de configuracao, UI administrativa e resolucao de politica
  efetiva.
- Endpoint administrativo `GET /dry_runs` para pre-visualizar, sem escrita, as
  conversas candidatas a distribuicao.
- Endpoint operacional
  `POST /conversations/:conversation_id/manual_assignment` para atribuicoes
  individuais do dashboard. Ele abre conversas pendentes ou adiadas, rejeita
  conversas encerradas sob lock, rejeita IDs malformados, exige que agentes de
  destino sejam atribuiveis ao canal e agenda uma
  rodada escopada quando a transferencia para departamento realmente entra na
  distribuicao privada. A atribuicao direta a agente nao entra na distribuicao.
  A validacao do destino usa consultas pontuais para o `AccountUser` e para a
  associacao ao canal, sem carregar toda a lista de agentes atribuiveis.
  Transferencias removem notificacoes e participacao obsoletas do responsavel
  anterior. Falha transitoria ao enfileirar a rodada imediata nao desfaz a
  transferencia confirmada; o erro fica no log e o watchdog periodico serve de
  recuperacao.
- Endpoint administrativo `POST /executions` para executar a atribuicao com
  auditoria. Por padrao, a execucao real fica bloqueada pela env
  `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`.
- Endpoint administrativo `GET/PATCH /automation_handoff_policies/:inbox_id`
  para configurar, por canal, o encaminhamento de conversas pendentes paradas
  na automacao. O watchdog executa essa etapa antes da atribuicao automatica,
  registra `automation_handoff_completed`/`automation_handoff_skipped` na
  auditoria e respeita a mesma env de execucao real.
- Endpoint administrativo `GET /supervisor_alerts` e rota frontend privada para
  listar atendimentos que passaram do limite configurado em `supervisor_alert`,
  com severidade calculada e filtros visuais por motivo, severidade, time e
  canal, sem alterar conversas. Administradores e supervisores Ibsoft podem
  acessar esta rota.
- Endpoint `GET /event_logs` e tela privada de auditoria para
  consultar `ibsoft_conversation_distribution_event_logs` com filtros,
  paginacao e dados de conversa, contato, time, canal e agentes. O filtro de
  conversa aceita o ID visivel exibido na UI do Chatwoot, inclusive com prefixo
  `#`, e preserva fallback para o ID interno gravado no evento. O ID da conversa
  abre o atendimento em nova aba. A interface mostra os tipos de evento apenas
  com rotulos traduzidos e nao exibe JSON bruto nem coluna de detalhes na
  tabela; `metadata` permanece disponivel na API para auditoria tecnica futura.
  Os filtros de canal e departamento usam seletores alimentados pelas stores
  nativas do Chatwoot. Administradores e supervisores Ibsoft podem acessar esta
  rota.
- A permissao privada `ibsoft_conversation_distribution_supervise` e gerenciada
  pela tela `Perfis e permissoes`, sem endpoints dedicados de supervisores.
- Endpoints de agente `GET /agent_assignments` e
  `POST /agent_assignments/claim`, usados pelo prompt privado que aparece ao
  agente online para assumir conversas aguardando nos seus departamentos.
- O prompt e o backend aplicam obrigatoriedade calculada pela configuracao
  global ChatHub, usando percentual da fila disponivel com minimo/maximo. A
  validacao final fica em
  `Ibsoft::ConversationDistribution::AgentAssignmentRequestGuard`, evitando que
  chamadas diretas para a API assumam conversas acima do limite ou ignorem
  conversas obrigatorias.
- Politicas de time podem gravar horario de funcionamento proprio
  (`business_hours.mode=custom`) com grade semanal, fuso horario e intervalos em
  `business_hours.breaks`, sem alterar a tela nativa de horario do canal.
- `ConfigurationValidator` valida fallback, mensagem automatica, timezone,
  grade semanal, intervalos e limites numericos antes de salvar politicas.
- Telas de politica Ibsoft exibem alerta quando autoatribuicao nativa do canal,
  autoatribuicao nativa do time ou politica nativa vinculada ainda podem
  concorrer com a distribuicao Ibsoft.
- Job automatico `Ibsoft::ConversationDistribution::WatchdogJob` registrado no
  cron, mas inerte por padrao pela env
  `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false`.
- Service `DecisionResolver` centraliza a decisao antes da atribuicao,
  considerando elegibilidade, politica efetiva, horario, intervalos e acao
  configurada para indisponibilidade.
- Service `AssignmentRoundLimiter` aplica o limite operacional da politica
  efetiva (`distribution.max_assignments_per_round`) por par canal/time no
  watchdog automatico. A env `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT`
  permanece apenas como teto tecnico de varredura por execucao.
- Service `AssignmentRateLimiter` usa sorted set em Redis por agente/janela
  para aplicar `fair_distribution_limit`, evitando varredura de chaves Redis em
  cada candidato quando a politica usa `assignment_limit_mode=assignment_window`.
- Service `AgentCapacityEvaluator` aplica
  `assignment_limit_mode=open_conversations`, contando apenas conversas abertas
  atribuidas ao agente na conta e ignorando etiquetas configuradas ou conversas
  aguardando resposta do cliente acima do prazo definido na politica.
- Service `AgentCapacityGuard` protege a decisao final com advisory lock
  transacional do PostgreSQL por conta e agente. A capacidade e recontada sob o
  lock antes da escrita; se outra instancia consumir a vaga, distribuicao e
  redistribuicao tentam o proximo agente elegivel. A garantia funciona entre
  processos, containers e instancias em autoscaling sem tabela ou contador
  adicional.
- `WatchdogRunner` usa lock distribuido em Redis por escopo
  (`IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS`, padrao 300s)
  para evitar rodadas concorrentes.
- O watchdog sincroniza `ibsoft_chathub_agent_presence_states` apenas quando
  `login_stabilization.enabled=true`, evitando varrer todos os usuarios da
  conta em politicas que nao usam janela pos-login.
- Service `DecisionActionExecutor` executa `notify_customer` e `fallback_team`
  com idempotencia, mantendo os efeitos colaterais protegidos pela flag de
  execucao real. O envio de mensagem automatica reserva a acao dentro do lock,
  cria a mensagem fora do lock da conversa e depois grava o resultado.
- Services `RedistributionCandidateFinder` e `RedistributionExecutor` executam a
  redistribuicao de conversas atribuidas pelo modulo Ibsoft quando o agente nao
  deu primeira resposta dentro do timeout configurado.
- Service `PreviousAssigneeParticipationCleanup` remove o agente anterior de
  `conversation_participants` apos uma redistribuicao real do modulo Ibsoft,
  evitando que ele continue recebendo notificacoes como participante. O fluxo
  nativo de transferencias manuais nao e alterado.
- Marcacao explicita da origem de transferencia para time em
  `additional_attributes.ibsoft_distribution_source`, sem executar atribuicao
  automatica. Nao ha mais inferencia ampla de transferencia manual apenas por a
  conversa estar aberta, sem agente e com time; conversas sem origem explicita
  ficam inelegiveis por seguranca.
- Eventos repetidos de `assignment_skipped` e `redistribution_skipped` sao
  deduplicados por janela configuravel via
  `IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS`, com padrao de
  15 minutos.
- Logs de auditoria possuem indices compostos para deduplicacao recente, busca
  do ultimo evento por conversa e filtros do dashboard de logs.
- Nenhum comportamento automatico de conversa fica ativo sem flag explicita.
- Nenhum callback de conversa, presenca de agente ou Assignment V2 foi alterado.
- A cobertura automatizada valida que o executor Ibsoft continua atribuindo
  conversas elegiveis com `assignment_v2` desligado, sem enfileirar o worker
  nativo do Assignment V2.
- A matriz automatizada tambem cobre origens permitidas/bloqueadas, precedencia
  time > canal, limite e ordem por `waiting_since`, falhas parciais, multiplos
  agentes online, limite de capacidade legado, filtros por canal/time e
  isolamento entre contas.
- A redistribuicao valida que apenas conversas com ultimo evento Ibsoft
  `assignment_completed` ou `redistribution_completed` sao candidatas, ignora
  reatribuicoes manuais e conversas ja respondidas, exclui o agente atual da
  rodada, respeita a flag de execucao real e usa o ultimo evento Ibsoft como
  novo marco de timeout.
- `Ibsoft::ConversationDistribution::AttentionNotificationSync` remove
  notificacoes de responsabilidade do agente anterior, lidas ou nao, depois de
  uma redistribuicao real, incluindo notificacoes de participante e preservando
  mencoes. Isso evita que a conversa permaneca em "Atencao" para quem deixou de
  ser responsavel sem tocar no listener nativo de notificacoes do Chatwoot.
- `assignmentAudioNotifications.js` toca o som configurado no perfil quando o
  evento realtime `assignee.changed` informa que a conversa foi atribuida ao
  usuario atual, respeitando audio desligado, aba ativa/inativa e conversa ja
  aberta na tela.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/conversation_distribution spec/services/ibsoft/conversation_distribution spec/requests/api/v1/accounts/ibsoft/conversation_distribution`
- `bundle exec rspec spec/jobs/ibsoft/conversation_distribution/watchdog_job_spec.rb spec/configs/schedule_spec.rb`
- `bundle exec rspec spec/models/ibsoft/conversation_distribution/automation_handoff_policy_spec.rb spec/services/ibsoft/conversation_distribution/automation_handoff_candidate_finder_spec.rb spec/services/ibsoft/conversation_distribution/automation_handoff_executor_spec.rb`
- `bundle exec rspec spec/controllers/api/v1/accounts/conversations/assignments_controller_spec.rb spec/services/action_service_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/conversationDistribution/specs/assignmentAudioNotifications.spec.js app/javascript/dashboard/helper/specs/actionCable.spec.js`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/conversationDistribution app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`

### 1.1 Analytics ChatHub Ibsoft

Documento detalhado: `IBSOFT_CHATHUB_ANALYTICS.md`.

Objetivo:

- Criar dashboards operacionais para agentes, supervisores e administradores.
- Exibir indicadores de tempo medio de resposta, primeira resposta, resolucao,
  backlog, redistribuicoes, saude por departamento, volume diario e distribuicao
  por horario.
- Consumir dados ja existentes do Chatwoot e do modulo de distribuicao Ibsoft
  sem alterar conversas, atribuicoes ou politicas.
- Servir como `Pagina inicial` do ChatHub. A mesma tela escolhe
  automaticamente entre dashboard de supervisao e dashboard do agente conforme
  as permissoes da conta atual.
- Para usuarios com permissao de supervisao, abrir o `Painel da equipe` por
  padrao, mas permitir alternar para `Meu painel` dentro da propria Home.
- Exibir o botao `Supervisao` dentro da Home apenas para administradores ou
  usuarios com permissao `ibsoft_conversation_distribution_supervise`.

Arquivos privados principais:

- `app/controllers/api/v1/accounts/ibsoft/chathub_analytics/`
- `app/services/ibsoft/chathub_analytics/`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/`
- `config/locales/ibsoft_chathub_analytics.en.yml`
- `config/locales/ibsoft_chathub_analytics.pt_BR.yml`
- `spec/**/ibsoft/chathub_analytics/`

Banco de dados:

- Nao cria tabelas novas.
- Usa `conversations`, `reporting_events` e
  `ibsoft_conversation_distribution_event_logs`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/chathub_analytics`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend `ibsoft_chathub_home` e mantem
  `ibsoft_chathub_analytics` como redirecionamento de compatibilidade.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona item
  de menu `Pagina inicial` do ChatHub como primeiro item, imediatamente antes
  de `Atencao`. O item direto de supervisao nao fica mais no menu principal.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: registram
  textos da UI.

Validacao recomendada:

- `bundle exec rspec spec/services/ibsoft/chathub_analytics spec/requests/api/v1/accounts/ibsoft/chathub_analytics/dashboards_spec.rb`
- `bundle exec rubocop app/services/ibsoft/chathub_analytics app/controllers/api/v1/accounts/ibsoft/chathub_analytics spec/services/ibsoft/chathub_analytics spec/requests/api/v1/accounts/ibsoft/chathub_analytics/dashboards_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/chathubAnalytics/specs/Index.spec.js`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/chathubAnalytics app/javascript/dashboard/routes/dashboard/dashboard.routes.js app/javascript/dashboard/components-next/sidebar/Sidebar.vue`

### 2. Chat interno Ibsoft

Documento detalhado: `IBSOFT_INTERNAL_CHAT.md`.

Objetivo:

- Permitir chat direto e salas entre agentes dentro do dashboard.
- Manter mensagens internas separadas de `Conversation`, `Inbox`, `Contact` e
  `Message` do atendimento a clientes.
- Suportar texto, imagens, videos, audios, arquivos, leitura, contador de nao
  lidos, eventos realtime e permissao por participante.
- Reproduzir audios por `blob:` local gerado sob demanda via endpoint
  protegido, apenas ao clicar em tocar/baixar, sem expor URL direta do
  ActiveStorage e sem aplicar cache-buster que invalide o objeto no navegador.

Arquivos privados principais:

- `app/controllers/api/v1/accounts/ibsoft/internal_chat/`
- `app/models/ibsoft/internal_chat/`
- `app/policies/ibsoft/internal_chat/`
- `app/services/ibsoft/internal_chat/`
- `app/javascript/dashboard/ibsoft/internalChat/`
- `app/javascript/dashboard/ibsoft/internalChat/components/InternalChatAudioChip.vue`
- `app/javascript/dashboard/ibsoft/internalChat/helpers/attachmentUrls.js`
- `app/javascript/dashboard/ibsoft/internalChat/helpers/attachmentLoader.js`
- `config/locales/ibsoft_internal_chat.en.yml`
- `config/locales/ibsoft_internal_chat.pt_BR.yml`
- `spec/**/ibsoft/internal_chat/`

Compatibilidade de storage e autoscaling:

- `app/services/ibsoft/internal_chat/attachment_blob_preparer.rb` envia arquivos
  ao Active Storage antes da transacao curta da mensagem e limpa blobs sem
  vinculo em falhas.
- `app/services/ibsoft/internal_chat/attachment_delivery.rb` mantem streaming
  no `Disk` e usa URL assinada de um minuto em storage remoto, sempre depois da
  autorizacao da sala.
- `app/services/ibsoft/internal_chat/attachment_preview_scheduler.rb` agenda
  previews pendentes com trava curta no Redis compartilhado, inclusive para
  anexos anteriores a esta adaptacao e em execucao com varias replicas.
- `app/models/ibsoft/internal_chat/attachment.rb` registra o preview nomeado
  `internal_chat_preview` para processamento assincrono pelo Active Storage.
- O endpoint de preview responde `202` enquanto o variant nao estiver pronto;
  `attachmentLoader.js` repete a consulta por tempo limitado.
- Nao ha nova variavel Ibsoft. Em autoscaling, usar a configuracao nativa
  `ACTIVE_STORAGE_SERVICE=amazon`, bucket privado, CORS e fila Sidekiq `default`.
- Nenhum novo arquivo do core do Chatwoot foi tocado por esta adaptacao.

Banco de dados:

- `db/migrate/20260510000000_create_ibsoft_internal_chat.rb`
- tabelas `ibsoft_internal_chat_rooms`,
  `ibsoft_internal_chat_memberships`, `ibsoft_internal_chat_messages` e
  `ibsoft_internal_chat_attachments`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/internal_chat`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend do chat interno.
- `app/javascript/dashboard/store/index.js`: registra a store
  `ibsoftInternalChat`.
- `app/javascript/dashboard/helper/actionCable.js`: registra eventos realtime
  `ibsoft.internal_chat.*` e delega para a store/helper privado.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona item
  de menu do chat interno e contador.
- `app/javascript/dashboard/i18n/locale/en/index.js` e
  `app/javascript/dashboard/i18n/locale/pt_BR/index.js`: carregam traducoes do
  modulo.

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/internal_chat spec/policies/ibsoft/internal_chat spec/services/ibsoft/internal_chat spec/requests/api/v1/accounts/ibsoft/internal_chat`
- abrir dashboard, criar sala, criar chat direto, enviar texto/anexo, remover
  membro, apagar sala e conferir contador realtime.

### 3. Conversas: automacao, protocolo e encerramento

Documento detalhado:
`app/javascript/dashboard/ibsoft/conversation/README.md`.

Objetivo:

- Exibir `pending` como `Automacao` nos pontos operacionais.
- Apresentar a aba operacional `Nao atribuidas` como `Fila`, preservando o
  estado interno `unassigned` e os textos tecnicos em outras areas.
- Remover a opcao manual de marcar conversa como pendente nos menus de
  atendimento, preservando APIs, macros e configuracoes de automacao.
- Exibir a aba primaria `Automacoes`, mantendo `Todas` acessivel no menu.
- Exibir protocolo operacional no formato `YYYYMMDD-accountId-conversationId`.
- Permitir pesquisar/filtrar conversas por protocolo sem criar coluna nova no
  banco.
- Apresentar `resolved` como `Encerrar atendimento` nos fluxos operacionais.
- Apresentar mensagens de atividade de abertura como
  `Conversa foi aberta por %{user_name}`, evitando o termo `reaberta` sem
  alterar o locale original do Chatwoot.
- Manter a contagem da aba `Automacoes` sincronizada quando uma conversa entra
  ou sai de `pending` por acoes locais de status.
- Manter `Minhas` e `Nao atribuidas` sincronizadas por eventos realtime mesmo
  enquanto `Automacoes` estiver selecionada, sem usar `pending` como recorte
  desses contadores operacionais.
- Agrupar rajadas de atualizacao do contador de `Automacoes`, ignorar respostas
  antigas e preservar o ultimo valor valido em falhas transitorias da API.
- Forcar conversas iniciadas manualmente por agente pela tela de nova mensagem
  a nascerem como `open`, mesmo em caixas com bot ativo, sem alterar o fluxo de
  clientes que entram de fora e devem continuar indo para `pending`.
- Abrir a visualizacao `Mencoes` com a aba `Todas` selecionada, garantindo que
  mencoes em conversas atribuidas a outro agente tambem aparecam na lista.
- Exigir que o agente assuma conversas sem responsavel ou retome conversas em
  automacao antes de responder, preservando notas privadas e rascunhos.
- Permitir colaboracao em conversas abertas atribuidas a outro agente humano
  sem substituir o responsavel atual; atribuicoes a bots continuam protegidas.

Arquivos privados principais:

- `app/javascript/dashboard/ibsoft/conversation/`
- `app/javascript/dashboard/ibsoft/conversation/replyAssignmentGuard.js`
- `app/javascript/dashboard/ibsoft/conversation/components/ReplyAssignmentGuardBanner.vue`
- `app/services/ibsoft/conversation/protocol.rb`
- `app/services/ibsoft/conversation/protocol_filter_payload.rb`
- `app/services/ibsoft/conversation/protocol_search.rb`
- `app/services/ibsoft/conversation/force_open_on_agent_created_conversation.rb`
- `app/services/ibsoft/conversation/resolved_attention_notification_cleanup.rb`
- `config/locales/zz_ibsoft_conversation.en.yml`
- `config/locales/zz_ibsoft_conversation.pt_BR.yml`

Pontos de acoplamento no Chatwoot original:

- `app/models/conversation.rb`: chama o service Ibsoft durante
  `determine_conversation_status`, antes da regra padrao que envia caixas com
  bot ativo para `pending`.
- `app/models/conversation.rb`: chama
  `Ibsoft::Conversation::ResolvedAttentionNotificationCleanup` no fluxo de
  encerramento da conversa. Este acoplamento e intencional e pequeno: remove
  notificacoes vinculadas a conversa encerrada para que ela saia imediatamente
  da tela `Atencao`, inclusive quando filtros de notificacoes lidas estiverem
  ativos, sem alterar a regra nativa de status.
- `app/javascript/dashboard/components-next/NewConversation/helpers/composeConversationHelper.js`:
  marca conversas criadas manualmente por agente com
  `ibsoft_force_open_on_create`.
- `app/javascript/dashboard/store/modules/contactConversations.js`: transporta
  `additionalAttributes` para `additional_attributes` em FormData e JSON.
- `app/finders/conversation_finder.rb`: delega busca textual por protocolo para
  `Ibsoft::Conversation::ProtocolSearch`.
- `app/services/search_service.rb`: inclui protocolo na busca global
  `/search`.
- `app/services/conversations/filter_service.rb`: expande filtro privado
  `ibsoft_protocol` para filtros nativos.
- `app/javascript/dashboard/components/ChatList.vue`: conecta tabs
  operacionais, contagem de automacoes, refresh de contadores em mudancas de
  status e exclusoes locais, mapeamento de `Automacoes` e aba inicial `Todas`
  para a visualizacao de `Mencoes`.
- `app/javascript/dashboard/components/ChatListHeader.vue`: usa helper Ibsoft
  para label de status.
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`:
  conecta o guard privado que bloqueia texto, anexos, audio e templates ate a
  atribuicao/retomada ser confirmada. Nenhuma store, API ou regra backend foi
  alterada para esse comportamento.
- `app/javascript/dashboard/components-next/filter/provider.js`: registra o
  filtro `Protocolo`.
- `app/javascript/dashboard/components/widgets/conversation/advancedFilterItems/index.js`:
  registra atributo de filtro `ibsoft_protocol`.
- `app/javascript/dashboard/store/modules/conversations/helpers/filterHelpers.js`:
  serializa o filtro de protocolo.
- `app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue`:
  exibe protocolo.
- `app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue`:
  exibe protocolo no header.
- `app/javascript/dashboard/components/widgets/conversation/ConversationBasicFilter.vue`:
  apresenta status com labels Ibsoft.
- `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue`:
  oculta `pending` manual e troca texto de encerramento.
- `app/javascript/dashboard/components/buttons/ResolveAction.vue`: troca
  apresentacao de resolver para encerrar atendimento, impede pendente manual e
  dispara refresh de contadores quando uma conversa sai de `pending`.
- `app/javascript/dashboard/components/widgets/conversation/conversationBulkActions/BulkUpdateActions.vue`:
  troca textos de encerramento em massa.
- `app/javascript/dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue`:
  troca textos de atributos obrigatorios no encerramento.
- `app/javascript/dashboard/composables/chatlist/useBulkActions.js`: mensagens
  de sucesso/erro do encerramento em massa e refresh de contadores quando uma
  acao em massa envolve `pending`.
- `app/javascript/dashboard/composables/commands/useBulkActionsHotKeys.js` e
  spec correspondente: atalhos de encerramento.
- `app/javascript/dashboard/helper/commandbar/actions.js`: texto do comando de
  encerramento.
- `app/javascript/dashboard/components/widgets/modal/constants.js` e
  `WootKeyShortcutModal.vue`: suporte a `titleKey` para atalhos com traducao
  Ibsoft.
- `app/javascript/dashboard/store/modules/conversations/actions.js` e
  `helpers/actionHelpers.js`: preservam contadores ao buscar automacoes.
- `app/javascript/dashboard/ibsoft/conversation/statusStatsRefresh.js`:
  centraliza a emissao de refresh dos contadores quando uma mudanca de status
  envolve `pending`.

Specs relacionadas:

- `spec/models/conversation_spec.rb`
- `spec/services/ibsoft/conversation/resolved_attention_notification_cleanup_spec.rb`
- `app/javascript/dashboard/components-next/NewConversation/helpers/specs/composeConversationHelper.spec.js`
- `app/javascript/dashboard/store/modules/specs/contactConversations/actions.spec.js`
- `spec/controllers/api/v1/accounts/search_controller_spec.rb`
- `spec/finders/conversation_finder_spec.rb`
- `spec/services/search_service_spec.rb`
- `app/javascript/dashboard/ibsoft/conversation/specs/statusPresentation.spec.js`
- `app/javascript/dashboard/ibsoft/conversation/specs/automationConversationStats.spec.js`

Risco principal:

- Este e o patch com maior numero de pontos no core. Em atualizacoes do
  upstream, revisar primeiro os arquivos de lista, filtro, busca, command bar e
  status de conversa.

### 4. Tema visual Ibsoft / ChatHub

Documento detalhado: `app/javascript/dashboard/ibsoft/theme/README.md`.

Objetivo:

- Aplicar identidade visual ChatHub/Ibsoft com baixo acoplamento.
- Personalizar tema escuro, sidebar, item ativo, empty states e logos.
- Ocultar seletor de idioma, versao/build e ID da conta via CSS personalizado,
  sem alterar componentes nativos para esses casos.
- Exibir LED SVG lilas pulsante em itens operacionais da sidebar enquanto seus
  contadores de nao lidos forem maiores que zero.
- Respeitar `INSTALLATION_NAME=ChatHub` em previews nativos que exibem o nome
  padrao `Chatwoot`.

Arquivos privados principais:

- `app/javascript/dashboard/ibsoft/theme/_dark-overrides.scss`
- `app/javascript/dashboard/ibsoft/theme/assets/chathub-logo-color.png`
- `app/javascript/dashboard/ibsoft/theme/assets/chathub-logo-white.png`
- `app/javascript/dashboard/ibsoft/theme/README.md`
- `app/javascript/dashboard/ibsoft/sidebar/SidebarPulseLed.vue`

Pontos de acoplamento no Chatwoot original:

- `app/javascript/dashboard/assets/scss/app.scss`: importa o SCSS privado.
- `app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyState.vue`:
  adiciona classes estaveis para substituicao visual por CSS.
- `app/javascript/dashboard/routes/dashboard/inbox/InboxEmptyState.vue`:
  adiciona classes estaveis e usa texto Ibsoft para o estado vazio da caixa de
  entrada.
- `app/javascript/dashboard/routes/dashboard/inbox/InboxView.vue`: remove
  override local de nota para usar fallback do empty state.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: ajusta
  sidebar recolhida/expandida, logo, seletor de empresa, icone do item
  operacional `Atencao`, contadores usados pelo LED e entrada do chat interno.
  O LED de `Conversas` usa `conversationUnreadCounts/getAllUnreadCount`.
- `app/javascript/dashboard/components-next/sidebar/SidebarGroup.vue`: renderiza
  o LED no estado recolhido da sidebar.
- `app/javascript/dashboard/components-next/sidebar/SidebarGroupHeader.vue`:
  renderiza o LED no estado expandido da sidebar e permite ocultar a contagem
  numerica quando o item usa LED.
- `app/javascript/dashboard/ibsoft/internalChat/views/InternalChat.vue`: usa
  classes estaveis para empty states, item selecionado do chat interno e altura
  inicial menor do composer.
- `app/javascript/dashboard/components/widgets/conversation/MessagesView.vue`:
  usa altura inicial menor no composer do chat com clientes.
- `app/javascript/dashboard/components/widgets/conversation/ResizableEditorWrapper.vue`:
  adiciona props genericas de altura mantendo os defaults originais do
  Chatwoot; o chat interno e o chat com clientes passam valores menores para
  iniciar com mais area de mensagens.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/SenderNameExamplePreview.vue`:
  usa o composable nativo `useBranding` para trocar o fallback visual
  `Chatwoot` pelo `INSTALLATION_NAME` configurado. O envio real de e-mail
  continua usando `Inbox#sanitized_business_name`.
- `app/javascript/sdk/bubbleHelpers.js`: troca a constante `bubbleSVG` do
  launcher do SDK por um icone de balao de conversa branco com barras vazadas,
  mantendo a personalizacao concentrada no ponto que cria
  `#woot-widget-bubble-icon`.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos do patch.

Risco principal:

- Seletores CSS com `:has()` reduzem acoplamento no core, mas podem quebrar se o
  markup do upstream mudar. Apos atualizar o Chatwoot, validar visualmente
  idioma, build, ID da conta, empty states, sidebar e listas.

### 5. Overrides de i18n Ibsoft

Objetivo:

- Sobrescrever textos pontuais sem editar arquivos oficiais de traducao do
  Chatwoot.
- Manter a area operacional de conversas como `Atencao`, por exemplo
  `INBOX.LIST.TITLE` e `SIDEBAR.INBOX`.
- Exibir o conceito administrativo de inbox como `Canais de comunicacao` nas
  telas de configuracao, filtros, relatorios, campanhas, integracoes e
  politicas.
- Exibir `Macros` como `Conjuntos de ações` no pt-BR, incluindo sidebar,
  cabecalho da conversa, accordion do painel lateral/contatos e tela de
  cadastro/listagem.
- Exibir acoes e mensagens de atribuicao de `time` como `departamento` no
  pt-BR, incluindo ações em massa, menu de conversa, automações, barra de
  comandos, conjuntos de ações, painel lateral, relatórios, auditoria, SLA e
  funções personalizadas. Textos de integrações externas, como Linear Teams,
  preservam a nomenclatura do serviço integrado.

Arquivos privados principais:

- `app/javascript/dashboard/ibsoft/i18n/mergeLocale.js`
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`
- `app/javascript/dashboard/i18n/locale/en/ibsoftInternalChat.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftInternalChat.json`

Pontos de acoplamento no Chatwoot original:

- `app/javascript/dashboard/i18n/locale/en/index.js`: importa traducoes Ibsoft e
  aplica merge profundo de overrides.
- `app/javascript/dashboard/i18n/locale/pt_BR/index.js`: importa traducoes
  Ibsoft e aplica merge profundo de overrides.

Risco principal:

- Se o upstream alterar a montagem dos locales, revisar estes dois arquivos e
  preservar o merge Ibsoft como ultimo passo.

### 6. Datas, horarios e tempos relativos localizados

Documentos detalhados:

- `app/javascript/shared/ibsoft/locale/README.md`
- `app/javascript/dashboard/ibsoft/localization/README.md`

Objetivo:

- Evitar datas/horarios em ingles quando a interface esta em portugues.
- Centralizar formatos em helper privado com fallback compativel.
- Cobrir mensagens, tooltips, snooze, busca, inbox, relatorios, billing,
  date picker, eventos SLA, Shopify e emails citados.
- Definir Brasilia (`America/Sao_Paulo`) como fuso padrao operacional da
  instalacao Ibsoft para canais de comunicacao e relatorios.
- Traduzir e ajustar a tela de horario de atendimento do canal de comunicacao
  sem editar os arquivos oficiais de locale do Chatwoot.
- Permitir intervalos/pausas dentro do horario de atendimento usando tabela
  Ibsoft separada, sem alterar a estrutura nativa de `working_hours`.

Arquivos privados principais:

- `app/javascript/shared/ibsoft/locale/dateTime.js`
- `app/javascript/shared/ibsoft/locale/README.md`
- `app/javascript/dashboard/ibsoft/localization/README.md`
- `app/javascript/dashboard/ibsoft/localization/defaultTimezone.js`
- `app/javascript/dashboard/ibsoft/localization/businessHoursDefaults.js`
- `app/javascript/dashboard/ibsoft/localization/workingHourBreaks.js`
- `app/services/ibsoft/localization/default_timezone.rb`
- `app/models/ibsoft/localization/working_hour_break.rb`
- `app/models/concerns/ibsoft/localization/account_default_timezone.rb`
- `app/models/concerns/ibsoft/localization/inbox_working_hour_breaks.rb`
- `app/models/concerns/ibsoft/localization/working_hour_break_aware.rb`
- `app/controllers/concerns/ibsoft/localization/inboxes_controller_working_hour_breaks.rb`
- `config/locales/zz_ibsoft_localization.en.yml`
- `config/locales/zz_ibsoft_localization.pt_BR.yml`
- `config/initializers/ibsoft_localization_defaults.rb`
- `db/migrate/20260630090000_set_ibsoft_default_timezone.rb`
- `db/migrate/20260630091000_create_ibsoft_working_hour_breaks.rb`
- `spec/models/ibsoft/localization/working_hour_break_spec.rb`
- `spec/factories/ibsoft/localization/working_hour_breaks.rb`

Pontos de acoplamento no Chatwoot original:

- `app/views/api/v1/models/_inbox.json.jbuilder`,
  `app/views/public/api/v1/models/_inbox.json.jbuilder` e
  `app/views/api/v1/widget/configs/create.json.jbuilder`: expoem
  `ibsoft_working_hour_breaks`.
- `app/javascript/shared/helpers/timeHelper.js`
- `app/javascript/shared/helpers/DateHelper.js`
- `app/javascript/dashboard/App.vue`
- `app/javascript/dashboard/routes/dashboard/settings/profile/UserLanguageSelect.vue`
- `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WeeklyAvailability.vue`:
  usa helper Ibsoft para o fuso padrao de horario de atendimento e traduz os
  nomes dos dias; tambem envia pausas de atendimento.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/BusinessDay.vue`:
  adiciona a UI de intervalos por dia.
- `app/javascript/dashboard/routes/dashboard/onboarding/account-details/useAccountEnrichment.js`:
  usa o fuso padrao Ibsoft quando a conta ainda nao possui timezone enriquecido.
- `app/javascript/widget/helpers/availabilityHelpers.js`,
  `app/javascript/widget/composables/useAvailability.js`,
  `app/javascript/widget/components/Availability/AvailabilityContainer.vue` e
  `app/javascript/widget/components/Availability/AvailabilityText.vue`:
  aplicam pausas no widget.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: sobrescreve textos
  de horario de atendimento por merge de locale Ibsoft.
- Componentes que usavam `date-fns/format` diretamente foram ajustados para
  usar `ibsoftFormatDate`.

Risco principal:

- Novos componentes do upstream podem voltar a usar `date-fns/format`
  diretamente. Ao atualizar, procurar por imports diretos de `format` em telas
  exibidas ao usuario.
- Se o upstream alterar a tela de disponibilidade da inbox, preservar apenas a
  delegacao para `businessHoursDefaults.js` e as traducoes via `ibsoftTheme`.
- Se o upstream alterar o widget ou o modelo `working_hours`, validar que
  `ibsoft_working_hour_breaks` continua sendo aplicado no backend e no widget.

Correcoes localizadas de compatibilidade com Vue I18n:

- `app/javascript/dashboard/i18n/locale/he/login.json`: escapa o `@` literal
  do placeholder de e-mail.
- `app/javascript/dashboard/i18n/locale/pt_BR/helpCenter.json`: escapa o `@`
  literal do placeholder de usuario das redes sociais.
- `app/javascript/dashboard/i18n/locale/sq/integrations.json`: usa a sintaxe
  de pluralizacao suportada pelo Vue I18n em duas mensagens do Captain.
- Essas tres alteracoes sao correcoes pontuais em traducoes nativas. Ao receber
  upstream, remover cada ajuste que ja tiver sido corrigido oficialmente.
- `app/javascript/dashboard/ibsoft/i18n/specs/translationCompiler.spec.js`
  protege essas mensagens e os literais privados usados pela distribuicao.

### 7. Imagem Docker privada

Documento detalhado: `docs/ibsoft-docker-image.md`.

Objetivo:

- Publicar imagem privada ChatHub/Chatwoot com customizacoes Ibsoft.
- Manter suporte a edicao Enterprise quando a instalacao possuir licenca/plano.

Arquivos relacionados:

- `docs/ibsoft-docker-image.md`
- `docker-compose.ibsoft.production.yaml`
- workflow GitHub Actions de publicacao da imagem privada, quando presente na
  branch de producao.

Cuidados:

- Nao commitar `.env`, backups, dumps, tokens ou segredos.
- `docker-compose.yaml` costuma ser local/desenvolvimento; revisar antes de
  incluir em commit de producao.

### 8. Backport temporario de retry para audio

Origem oficial: `chatwoot/chatwoot#13675` (`fix/audio-retry`).

> [!IMPORTANT]
> AVISO PARA A PROXIMA SINCRONIZACAO: este codigo nao e uma customizacao Ibsoft
> permanente. Ele replica temporariamente uma correcao oficial ainda nao
> incorporada ao `upstream/develop` no momento da aplicacao. Antes de resolver
> conflitos ou aceitar alteracoes nesses arquivos, verifique o estado do PR
> oficial e compare o codigo do upstream. Nao mantenha duas implementacoes de
> retry para o mesmo carregamento de audio.

Objetivo:

- Repetir o carregamento de audios recebidos em tempo real quando a primeira
  URL temporaria do Active Storage responder antes de o arquivo estar pronto.
- Evitar que o agente precise recarregar a pagina depois de um `404` inicial.

Pontos nativos tocados pelo backport:

- `app/javascript/dashboard/components-next/message/bubbles/Audio.vue`
- `app/javascript/dashboard/composables/loadWithRetry.js`
- `app/javascript/dashboard/i18n/locale/en/settings.json`

Complementos privados:

- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: traducao do
  estado de audio indisponivel.
- `app/javascript/dashboard/ibsoft/upstreamBackports/specs/audioLoadWithRetry.spec.js`:
  cobre sucesso, retry com cache busting e falha definitiva.

Remocao futura:

- Consultar `https://github.com/chatwoot/chatwoot/pull/13675` e confirmar se o
  PR, ou uma correcao equivalente, entrou em `upstream/develop`.
- Comparar os tres arquivos nativos com a versao oficial antes de resolver
  conflitos. Se o upstream ja contiver a correcao, preferir o codigo oficial.
- Remover somente o codigo duplicado do backport. Preservar a traducao pt-BR
  privada caso o upstream ainda nao forneca uma traducao equivalente.
- Reavaliar ou remover o spec privado quando a cobertura oficial equivalente
  existir; enquanto isso, ele deve continuar validando o comportamento.
- Depois da sincronizacao, executar o spec
  `app/javascript/dashboard/ibsoft/upstreamBackports/specs/audioLoadWithRetry.spec.js`
  e testar manualmente um audio recebido em tempo real sem recarregar a pagina.

### 9. Perfil: visibilidade de senha e sessoes em pt-BR

Objetivo:

- Permitir visualizar individualmente os tres campos da troca de senha.
- Traduzir integralmente a secao de sessoes ativas para portugues do Brasil.

Pontos nativos tocados:

- `app/javascript/dashboard/routes/dashboard/settings/profile/ChangePassword.vue`

Traducoes privadas:

- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`

Teste:

- `app/javascript/dashboard/routes/dashboard/settings/profile/specs/ChangePassword.spec.js`

Acoplamento e cuidados:

- A composicao dos botoes de visibilidade e local a tela de senha; o componente
  global `woot-input` permanece intocado.
- Os arquivos `settings.json` nativos permanecem intocados; as chaves adicionais
  e a traducao pt-BR de sessoes usam o agregador privado de locale.
- Os botoes usam componentes, icones e tokens de tema existentes e possuem
  rotulos acessiveis traduzidos.
- Ao receber atualizacoes do upstream, conferir se a tela oficial passou a
  oferecer visibilidade de senha ou se o `woot-input` foi substituido. Nesse
  caso, remover a composicao duplicada e preservar apenas as traducoes ainda
  ausentes.

### 10. Gerenciamento de modelos da Meta

Documento detalhado: `IBSOFT_META_TEMPLATES.md`.

Objetivo:

- Gerenciar modelos do WhatsApp Business Cloud por uma tela privada acessivel
  apenas a administradores.
- Reutilizar a Graph API e o cache nativo do canal sem criar tabelas ou
  duplicar o catalogo no banco.
- Listar os modelos mais recentes primeiro e exibir a data de criacao/ultima
  atualizacao retornada pela Meta.
- Criar e editar modelos padrao, catalogo, detalhes/status do pedido,
  solicitacao de permissao para ligacao e autenticacao, com previa, variaveis,
  acoes compativeis e amostras de midia.

Arquivos privados principais:

- `app/controllers/api/v1/accounts/ibsoft/meta_templates/`
- `app/services/ibsoft/meta_templates/`
- `app/javascript/dashboard/ibsoft/metaTemplates/`
- `config/locales/ibsoft_meta_templates.*.yml`
- `app/javascript/dashboard/i18n/locale/*/ibsoftMetaTemplates.json`
- `spec/**/ibsoft/meta_templates/`

Banco de dados:

- Nenhuma tabela ou migration propria.
- Reutiliza `message_templates` e `message_templates_last_updated` do canal
  WhatsApp nativo.

Pontos de acoplamento:

- `config/routes.rb`: registra as rotas privadas da API.
- `app/javascript/dashboard/ibsoft/chathubSettings/routes.js`: agrega as rotas
  frontend privadas.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`:
  adiciona o atalho no card do canal.
- `app/javascript/dashboard/i18n/locale/en/index.js` e
  `app/javascript/dashboard/i18n/locale/pt_BR/index.js`: registram os arquivos
  de traducao privados.

Validacao recomendada:

- `bundle exec rspec spec/services/ibsoft/meta_templates spec/requests/api/v1/accounts/ibsoft/meta_templates`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/metaTemplates/specs app/javascript/dashboard/ibsoft/i18n/specs/translationCompiler.spec.js`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/metaTemplates`

## Arquivos sensiveis para conflito

Estes arquivos originais do Chatwoot contem pontos de acoplamento Ibsoft. Em
sincronizacoes com upstream, revise cada um deles quando aparecer conflito ou
quando o upstream alterar a mesma area.

### Backend Rails

- `config/initializers/ibsoft_localization_defaults.rb`
- `config/routes.rb`
- `config/schedule.yml`
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`
- `app/views/api/v1/models/_user.json.jbuilder`
- `app/finders/conversation_finder.rb`
- `app/services/action_service.rb`
- `app/services/search_service.rb`
- `app/services/conversations/filter_service.rb`
- `db/schema.rb`

### Frontend: bootstrap, rotas, store e realtime

- `app/javascript/dashboard/App.vue`
- `app/javascript/dashboard/assets/scss/app.scss`
- `app/javascript/dashboard/helper/actionCable.js`
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`
- `app/javascript/dashboard/store/index.js`
- `app/javascript/dashboard/i18n/locale/en/index.js`
- `app/javascript/dashboard/i18n/locale/pt_BR/index.js`

### Frontend: sidebar, inbox e empty states

- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/components-next/sidebar/SidebarGroup.vue`
- `app/javascript/dashboard/components-next/sidebar/SidebarGroupHeader.vue`
- `app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyState.vue`
- `app/javascript/dashboard/routes/dashboard/inbox/InboxEmptyState.vue`
- `app/javascript/dashboard/routes/dashboard/inbox/InboxView.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`

### Frontend: conversas, filtros e acoes

- `app/javascript/dashboard/components/ChatList.vue`
- `app/javascript/dashboard/components/ChatListHeader.vue`
- `app/javascript/dashboard/components-next/filter/provider.js`
- `app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue`
- `app/javascript/dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue`
- `app/javascript/dashboard/components/buttons/ResolveAction.vue`
- `app/javascript/dashboard/components/widgets/conversation/ConversationBasicFilter.vue`
- `app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue`
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
- `app/javascript/dashboard/components/widgets/conversation/advancedFilterItems/index.js`
- `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue`
- `app/javascript/dashboard/components/widgets/conversation/conversationBulkActions/BulkUpdateActions.vue`
- `app/javascript/dashboard/components/widgets/modal/WootKeyShortcutModal.vue`
- `app/javascript/dashboard/components/widgets/modal/constants.js`
- `app/javascript/dashboard/composables/chatlist/useBulkActions.js`
- `app/javascript/dashboard/composables/commands/useBulkActionsHotKeys.js`
- `app/javascript/dashboard/composables/commands/spec/useBulkActionsHotKeys.spec.js`
- `app/javascript/dashboard/helper/commandbar/actions.js`
- `app/javascript/dashboard/store/modules/conversations/actions.js`
- `app/javascript/dashboard/store/modules/conversations/helpers/actionHelpers.js`
- `app/javascript/dashboard/store/modules/conversations/helpers/filterHelpers.js`
- `app/javascript/dashboard/ibsoft/conversation/statusStatsRefresh.js`

### Frontend: datas e horarios

- `app/javascript/widget/helpers/availabilityHelpers.js`
- `app/javascript/widget/composables/useAvailability.js`
- `app/javascript/widget/components/Availability/AvailabilityContainer.vue`
- `app/javascript/widget/components/Availability/AvailabilityText.vue`
- `app/javascript/shared/helpers/timeHelper.js`
- `app/javascript/shared/helpers/DateHelper.js`
- `app/javascript/dashboard/routes/dashboard/onboarding/account-details/useAccountEnrichment.js`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WeeklyAvailability.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/BusinessDay.vue`
- `app/javascript/dashboard/routes/dashboard/settings/profile/UserLanguageSelect.vue`
- `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`

### Frontend: perfil

- `app/javascript/dashboard/routes/dashboard/settings/profile/ChangePassword.vue`
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`

## Arquivos locais/temporarios que exigem auditoria

Estes arquivos apareceram como alterados ou temporarios em algum momento do
workspace e devem ser avaliados antes de qualquer commit/push de producao:

- `lib/chatwoot_hub.rb`
- `lib/chatwoot_hub.rb.backup.*`
- `docker-compose.yaml`
- `app/models/category.rb`
- `app/models/platform_banner.rb`
- `enterprise/app/models/captain/document.rb`
- `enterprise/app/models/company.rb`

Nao assumir que esses arquivos pertencem aos modulos privados sem conferir o
diff atual e a intencao da branch.

## Checklist ao criar novo modulo privado

1. Criar diretorio proprio em `app/**/ibsoft/<modulo>` ou
   `app/javascript/**/ibsoft/<modulo>`.
2. Criar services, policies, componentes, store, rotas e traducoes proprias.
3. Tocar no core somente para registrar rota, menu, store, i18n ou handler.
4. Documentar o modulo em um `.md` proprio.
5. Adicionar neste arquivo:
   - objetivo;
   - arquivos privados;
   - dependencias;
   - pontos de acoplamento;
   - testes;
   - riscos ao atualizar upstream.
6. Criar testes proporcionais ao risco.
7. Validar tema claro/escuro e textos traduzidos.

## Checklist minimo depois de atualizar upstream

- `git diff --check`
- `bundle exec rails db:migrate`
- `bundle exec rspec spec/models/ibsoft/internal_chat spec/policies/ibsoft/internal_chat spec/services/ibsoft/internal_chat spec/requests/api/v1/accounts/ibsoft/internal_chat`
- `bundle exec rspec spec/services/search_service_spec.rb spec/finders/conversation_finder_spec.rb spec/controllers/api/v1/accounts/search_controller_spec.rb`
- `node --check app/javascript/dashboard/ibsoft/conversation/statusPresentation.js`
- `node --check app/javascript/dashboard/ibsoft/conversation/statusStatsRefresh.js`
- `node --check app/javascript/dashboard/ibsoft/conversation/protocol.js`
- `node --check app/javascript/dashboard/ibsoft/i18n/mergeLocale.js`
- validar manualmente: sidebar, Atencao, conversas, Automacoes, Protocolo,
  Encerrar atendimento, chat interno, anexos, realtime, tema claro/escuro e
  ocultacoes visuais.

## Regra de atualizacao deste arquivo

Este arquivo deve ser tratado como contrato operacional da nossa camada privada.
Se uma customizacao nova nao esta descrita aqui, ela esta invisivel para o
proximo merge com upstream e aumenta o risco de perda ou conflito silencioso.
