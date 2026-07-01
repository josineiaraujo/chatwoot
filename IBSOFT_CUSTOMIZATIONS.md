# Mapa de customizacoes Ibsoft

Este arquivo e o inventario raiz das customizacoes privadas aplicadas sobre o
Chatwoot. Antes de atualizar com `upstream/develop`, fazer rebase, resolver
conflitos ou preparar uma imagem de producao, leia este arquivo para garantir
que todos os pontos privados foram preservados.

Regra permanente: qualquer novo modulo, patch, arquivo Ibsoft, migracao,
traducao, ponto de acoplamento no core ou dependencia tecnica deve ser
registrado aqui no mesmo commit da mudanca.

## Como usar antes de sincronizar com upstream

1. Atualize a branch alinhada ao Chatwoot oficial:
   `git switch develop`, `git fetch upstream`, `git merge --ff-only upstream/develop`.
2. Leia as secoes `Pontos de acoplamento no Chatwoot original` e
   `Arquivos sensiveis para conflito`.
3. Atualize/rebaseie as branches privadas sobre `develop`.
4. Resolva primeiro os pontos de acoplamento pequenos no core.
5. Depois valide os modulos isolados em `app/**/ibsoft` e
   `app/javascript/**/ibsoft`.
6. Rode migracoes, testes e lint proporcionais aos modulos afetados.
7. Verifique manualmente os fluxos visuais do dashboard antes de publicar.

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

### 0. Distribuicao de atendimentos Ibsoft

Documento detalhado: `IBSOFT_CONVERSATION_DISTRIBUTION.md`.

Objetivo:

- Criar uma politica privada de distribuicao e redistribuicao de atendimentos
  humanos, separada do Assignment V2 como motor executor.
- Permitir configuracao padrao por canal de comunicacao e sobrescrita por time.
- Preparar suporte a horarios de funcionamento por time, fallback, alerta de
  supervisor e auditoria de redistribuicoes.

Arquivos privados principais:

- `app/models/ibsoft/conversation_distribution/`
- `app/services/ibsoft/conversation_distribution/`
- `app/jobs/ibsoft/conversation_distribution/`
- `app/controllers/api/v1/accounts/ibsoft/conversation_distribution/`
- `app/javascript/dashboard/ibsoft/conversationDistribution/`
- `spec/**/ibsoft/conversation_distribution/`

Banco de dados:

- `db/migrate/20260701090000_create_ibsoft_conversation_distribution.rb`
- tabelas `ibsoft_conversation_distribution_channel_policies`,
  `ibsoft_conversation_distribution_team_policies` e
  `ibsoft_conversation_distribution_event_logs`.

Pontos de acoplamento no Chatwoot original:

- `config/routes.rb`: registra rotas API do namespace
  `/api/v1/accounts/:account_id/ibsoft/conversation_distribution`.
- `config/schedule.yml`: registra o cron privado
  `ibsoft_conversation_distribution_watchdog_job`, inerte por flag.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`:
  registra a secao de distribuicao de atendimentos na configuracao do canal.
- `app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue`: registra
  o botao de configuracao de distribuicao por time.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: registram
  textos da UI do modulo.
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`:
  marca origem Ibsoft quando uma conversa e atribuida a time via API/UI.
- `app/services/action_service.rb`: marca origem Ibsoft quando uma acao,
  automacao ou macro atribui a conversa a um time.

Estado atual:

- Incremento inicial de configuracao, UI administrativa e resolucao de politica
  efetiva.
- Endpoint administrativo `GET /dry_runs` para pre-visualizar, sem escrita, as
  conversas candidatas a distribuicao.
- Endpoint administrativo `POST /executions` para executar a atribuicao com
  auditoria. Por padrao, a execucao real fica bloqueada pela env
  `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`.
- Job automatico `Ibsoft::ConversationDistribution::WatchdogJob` registrado no
  cron, mas inerte por padrao pela env
  `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false`.
- Service `DecisionResolver` centraliza a decisao antes da atribuicao,
  considerando elegibilidade, politica efetiva, horario e acao configurada para
  indisponibilidade.
- Service `DecisionActionExecutor` executa `notify_customer` e `fallback_team`
  com idempotencia, mantendo os efeitos colaterais protegidos pela flag de
  execucao real.
- Services `RedistributionCandidateFinder` e `RedistributionExecutor` executam a
  redistribuicao de conversas atribuidas pelo modulo Ibsoft quando o agente nao
  deu primeira resposta dentro do timeout configurado.
- Marcacao explicita da origem de transferencia para time em
  `additional_attributes.ibsoft_distribution_source`, sem executar atribuicao
  automatica.
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

Validacao recomendada:

- `bundle exec rspec spec/models/ibsoft/conversation_distribution spec/services/ibsoft/conversation_distribution spec/requests/api/v1/accounts/ibsoft/conversation_distribution`
- `bundle exec rspec spec/jobs/ibsoft/conversation_distribution/watchdog_job_spec.rb spec/configs/schedule_spec.rb`
- `bundle exec rspec spec/controllers/api/v1/accounts/conversations/assignments_controller_spec.rb spec/services/action_service_spec.rb`
- `pnpm exec eslint app/javascript/dashboard/ibsoft/conversationDistribution app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`

### 1. Chat interno Ibsoft

Documento detalhado: `IBSOFT_INTERNAL_CHAT.md`.

Objetivo:

- Permitir chat direto e salas entre agentes dentro do dashboard.
- Manter mensagens internas separadas de `Conversation`, `Inbox`, `Contact` e
  `Message` do atendimento a clientes.
- Suportar texto, imagens, videos, audios, arquivos, leitura, contador de nao
  lidos, eventos realtime e permissao por participante.

Arquivos privados principais:

- `app/controllers/api/v1/accounts/ibsoft/internal_chat/`
- `app/models/ibsoft/internal_chat/`
- `app/policies/ibsoft/internal_chat/`
- `app/services/ibsoft/internal_chat/`
- `app/javascript/dashboard/ibsoft/internalChat/`
- `config/locales/ibsoft_internal_chat.en.yml`
- `config/locales/ibsoft_internal_chat.pt_BR.yml`
- `spec/**/ibsoft/internal_chat/`

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

### 2. Conversas: automacao, protocolo e encerramento

Documento detalhado:
`app/javascript/dashboard/ibsoft/conversation/README.md`.

Objetivo:

- Exibir `pending` como `Automacao` nos pontos operacionais.
- Remover a opcao manual de marcar conversa como pendente nos menus de
  atendimento, preservando APIs, macros e configuracoes de automacao.
- Exibir a aba primaria `Automacoes`, mantendo `Todas` acessivel no menu.
- Exibir protocolo operacional no formato `YYYYMMDD-accountId-conversationId`.
- Permitir pesquisar/filtrar conversas por protocolo sem criar coluna nova no
  banco.
- Apresentar `resolved` como `Encerrar atendimento` nos fluxos operacionais.
- Manter a contagem da aba `Automacoes` sincronizada quando uma conversa entra
  ou sai de `pending` por acoes locais de status.
- Forcar conversas iniciadas manualmente por agente pela tela de nova mensagem
  a nascerem como `open`, mesmo em caixas com bot ativo, sem alterar o fluxo de
  clientes que entram de fora e devem continuar indo para `pending`.

Arquivos privados principais:

- `app/javascript/dashboard/ibsoft/conversation/`
- `app/services/ibsoft/conversation/protocol.rb`
- `app/services/ibsoft/conversation/protocol_filter_payload.rb`
- `app/services/ibsoft/conversation/protocol_search.rb`
- `app/services/ibsoft/conversation/force_open_on_agent_created_conversation.rb`
- `config/locales/zz_ibsoft_conversation.en.yml`
- `config/locales/zz_ibsoft_conversation.pt_BR.yml`

Pontos de acoplamento no Chatwoot original:

- `app/models/conversation.rb`: chama o service Ibsoft durante
  `determine_conversation_status`, antes da regra padrao que envia caixas com
  bot ativo para `pending`.
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
  status e mapeamento de `Automacoes`.
- `app/javascript/dashboard/components/ChatListHeader.vue`: usa helper Ibsoft
  para label de status.
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
- `app/javascript/dashboard/components-next/NewConversation/helpers/specs/composeConversationHelper.spec.js`
- `app/javascript/dashboard/store/modules/specs/contactConversations/actions.spec.js`
- `spec/controllers/api/v1/accounts/search_controller_spec.rb`
- `spec/finders/conversation_finder_spec.rb`
- `spec/services/search_service_spec.rb`

Risco principal:

- Este e o patch com maior numero de pontos no core. Em atualizacoes do
  upstream, revisar primeiro os arquivos de lista, filtro, busca, command bar e
  status de conversa.

### 3. Tema visual Ibsoft / ChatHub

Documento detalhado: `app/javascript/dashboard/ibsoft/theme/README.md`.

Objetivo:

- Aplicar identidade visual ChatHub/Ibsoft com baixo acoplamento.
- Personalizar tema escuro, sidebar, item ativo, empty states e logos.
- Ocultar seletor de idioma, versao/build e ID da conta via CSS personalizado,
  sem alterar componentes nativos para esses casos.
- Exibir LED SVG lilas pulsante em itens operacionais da sidebar enquanto seus
  contadores de nao lidos forem maiores que zero.

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
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos do patch.

Risco principal:

- Seletores CSS com `:has()` reduzem acoplamento no core, mas podem quebrar se o
  markup do upstream mudar. Apos atualizar o Chatwoot, validar visualmente
  idioma, build, ID da conta, empty states, sidebar e listas.

### 4. Overrides de i18n Ibsoft

Objetivo:

- Sobrescrever textos pontuais sem editar arquivos oficiais de traducao do
  Chatwoot.
- Manter a area operacional de conversas como `Atencao`, por exemplo
  `INBOX.LIST.TITLE` e `SIDEBAR.INBOX`.
- Exibir o conceito administrativo de inbox como `Canais de comunicacao` nas
  telas de configuracao, filtros, relatorios, campanhas, integracoes e
  politicas.

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

### 5. Datas, horarios e tempos relativos localizados

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

### 6. Imagem Docker privada

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

## Arquivos sensiveis para conflito

Estes arquivos originais do Chatwoot contem pontos de acoplamento Ibsoft. Em
sincronizacoes com upstream, revise cada um deles quando aparecer conflito ou
quando o upstream alterar a mesma area.

### Backend Rails

- `config/initializers/ibsoft_localization_defaults.rb`
- `config/routes.rb`
- `config/schedule.yml`
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`
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

### Frontend: conversas, filtros e acoes

- `app/javascript/dashboard/components/ChatList.vue`
- `app/javascript/dashboard/components/ChatListHeader.vue`
- `app/javascript/dashboard/components-next/filter/provider.js`
- `app/javascript/dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue`
- `app/javascript/dashboard/components-next/ConversationWorkflow/ConversationResolveAttributesModal.vue`
- `app/javascript/dashboard/components/buttons/ResolveAction.vue`
- `app/javascript/dashboard/components/widgets/conversation/ConversationBasicFilter.vue`
- `app/javascript/dashboard/components/widgets/conversation/ConversationHeader.vue`
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
