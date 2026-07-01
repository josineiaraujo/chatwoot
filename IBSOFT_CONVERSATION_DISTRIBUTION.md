# Distribuicao de atendimentos Ibsoft

## Objetivo

Criar uma politica privada, configuravel e auditavel para distribuir e
redistribuir atendimentos humanos no ChatHub, sem depender do Assignment V2 como
motor concorrente.

O modulo deve atuar somente em conversas elegiveis, principalmente:

- handoff do robo para atendimento humano;
- transferencia automatica para time;
- transferencia manual de um agente para outro time.

O modulo nao deve interferir em:

- conversas iniciadas por agentes;
- atribuicoes manuais diretas para um agente;
- conversas que ja receberam primeira resposta humana depois da entrada na fila;
- conversas resolvidas, silenciadas ou ainda conduzidas pela automacao.

## Estrutura inicial

Backend isolado:

- `app/models/ibsoft/conversation_distribution/channel_policy.rb`
- `app/models/ibsoft/conversation_distribution/team_policy.rb`
- `app/models/ibsoft/conversation_distribution/event_log.rb`
- `app/models/ibsoft/conversation_distribution/configuration.rb`
- `app/services/ibsoft/conversation_distribution/candidate_finder.rb`
- `app/services/ibsoft/conversation_distribution/source_resolver.rb`
- `app/services/ibsoft/conversation_distribution/source_marker.rb`
- `app/services/ibsoft/conversation_distribution/candidate_evaluator.rb`
- `app/services/ibsoft/conversation_distribution/dry_run_preview.rb`
- `app/services/ibsoft/conversation_distribution/execution_config.rb`
- `app/services/ibsoft/conversation_distribution/decision_resolver.rb`
- `app/services/ibsoft/conversation_distribution/decision_action_executor.rb`
- `app/services/ibsoft/conversation_distribution/event_logger.rb`
- `app/services/ibsoft/conversation_distribution/assignment_executor.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_candidate_finder.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_executor.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_policy.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_result_builder.rb`
- `app/services/ibsoft/conversation_distribution/watchdog_runner.rb`
- `app/services/ibsoft/conversation_distribution/effective_policy_resolver.rb`
- `app/jobs/ibsoft/conversation_distribution/watchdog_job.rb`
- `app/controllers/api/v1/accounts/ibsoft/conversation_distribution/`

Frontend isolado:

- `app/javascript/dashboard/ibsoft/conversationDistribution/api.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/policyDefaults.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/DistributionPolicyForm.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/InboxDistributionSettings.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/TeamDistributionSettingsModal.vue`

Banco de dados:

- `ibsoft_conversation_distribution_channel_policies`
- `ibsoft_conversation_distribution_team_policies`
- `ibsoft_conversation_distribution_event_logs`

## Politicas

### Canal de comunicacao

A politica do canal define o comportamento padrao para conversas daquele canal:

- ativar/desativar distribuicao;
- fontes elegiveis;
- estrategia e limites de distribuicao;
- redistribuicao por falta de primeira resposta;
- comportamento sem atendente disponivel;
- horario/fallback padrao;
- alerta de supervisor.

### Time

A politica do time pode sobrescrever a politica do canal.

A precedencia planejada e:

1. politica especifica do time, quando `override_channel_policy=true`;
2. politica do canal de comunicacao;
3. padrao global Ibsoft, desativado.

O time tambem pode ter horario proprio. O campo `business_hours.mode` aceita:

- `inherit_channel`: usa o horario do canal;
- `custom`: usa horario proprio do time;
- `always_available`: considera o time sempre disponivel.

## API inicial

Todas as rotas ficam sob:

`/api/v1/accounts/:account_id/ibsoft/conversation_distribution`

Rotas:

- `GET /inbox_policies/:inbox_id`
- `PATCH /inbox_policies/:inbox_id`
- `GET /team_policies/:team_id`
- `PATCH /team_policies/:team_id`
- `POST /team_policies/copy`
- `GET /effective_policy?inbox_id=:inbox_id&team_id=:team_id`
- `GET /dry_runs?inbox_id=:inbox_id&team_id=:team_id&limit=:limit`
- `POST /executions`

Nesta fase, a API e administrativa. O papel de supervisor sera tratado em uma
politica propria quando o dashboard de supervisao for implementado.

## Dry-run de elegibilidade

O endpoint `dry_runs` monta uma pre-visualizacao somente leitura das conversas
que seriam candidatas a distribuicao.

Filtros iniciais:

- conversa `open`;
- sem agente humano atribuido (`assignee_id` vazio);
- com time definido;
- sem primeira resposta humana (`first_reply_created_at` vazio);
- respeitando `inbox_id`, `team_id` e `limit` quando enviados.

O `dry-run` nao altera `Conversation`, nao cria jobs e nao grava eventos. Ele
retorna os motivos de inelegibilidade quando a conversa esta na fila analisada,
por exemplo:

- `policy_disabled`;
- `source_not_allowed`;
- `missing_waiting_since`;
- `first_human_reply_present`;
- `human_assignee_present`.

Origem da conversa:

- `bot_handoff`: detectada por `reporting_events.name =
  conversation_bot_handoff`;
- `manual_team_transfer`: marcada quando um usuario transfere a conversa para
  um time ou inferida quando a conversa esta aberta, sem agente humano, com
  time e sem primeira resposta humana;
- `system_team_transfer`: marcada quando uma automacao ou `AgentBot` transfere
  a conversa para um time.

A inferencia de transferencia para time fica como fallback para conversas antigas
ou fluxos que ainda nao passaram pelo marcador explicito.

## Execucao de atribuicao

O endpoint `POST /executions` executa o mesmo fluxo do `dry-run`, mas registra
eventos de auditoria em `ibsoft_conversation_distribution_event_logs`.

Por padrao, a execucao real fica bloqueada pela flag global:

`IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`

O job automatico tambem fica bloqueado por uma flag separada:

`IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false`

O limite por rodada do job pode ser ajustado por:

`IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT=50`

Com a flag desligada:

- nenhuma conversa recebe `assignee_id`;
- cada candidata elegivel gera log `assignment_skipped` com reason
  `real_assignment_disabled`;
- o payload retorna resumo por motivo.

Com a flag ligada:

- o `DecisionResolver` classifica a conversa antes de tentar atribuir;
- a decisao considera elegibilidade, politica efetiva e horario de atendimento;
- o `DecisionActionExecutor` executa efeitos colaterais configurados para
  indisponibilidade, com idempotencia por conversa;
- o executor considera apenas candidatas elegiveis pela politica efetiva;
- seleciona agente online pertencente ao time e ao canal de comunicacao;
- respeita `member_ids_with_assignment_capacity`, incluindo filtros Enterprise
  quando presentes;
- captura a conversa com `FOR UPDATE SKIP LOCKED` antes de gravar assignee;
- grava `assignment_completed` com `new_assignee_id` quando atribui;
- grava `assignment_skipped` com `no_available_agent` quando nao ha agente
  online/capaz.
- executa `notify_customer` criando uma mensagem outgoing automatica sem
  usuario remetente, para nao marcar primeira resposta humana;
- executa `fallback_team` movendo a conversa para o time configurado, removendo
  assignee e marcando a origem como `system_team_transfer`;
- evita repetir a mesma mensagem/fallback em execucoes futuras usando
  `additional_attributes.ibsoft_distribution_action_records`;
- evita ciclos simples de fallback usando
  `additional_attributes.ibsoft_distribution_fallback_team_ids`.
- nao depende do Assignment V2 nativo estar ligado. A suite automatizada valida
  explicitamente o cenario com `assignment_v2` desligado, incluindo:
  - worker periodico nativo sem enfileirar `AutoAssignment::AssignmentJob`;
  - execucao real via endpoint Ibsoft atribuindo conversa elegivel;
  - origens `bot_handoff`, `manual_team_transfer` e
    `system_team_transfer`;
  - bloqueio quando a origem nao e permitida pela politica efetiva;
  - precedencia de politica de time sobre politica de canal, tanto para ativar
    quanto para bloquear distribuicao;
  - ordenacao por conversa aguardando ha mais tempo e limite de execucao;
  - continuidade do processamento quando uma candidata e inelegivel;
  - distribuicao de conversas acumuladas entre multiplos agentes online;
  - respeito ao limite legado de capacidade do canal quando Assignment V2 esta
    desligado;
  - escopo por `inbox_id`, `team_id` e `account`;
  - bloqueio quando o agente online nao pertence ao time e ao canal;
  - bloqueio quando o time desativou autoatribuicao;
  - protecao contra sobrescrever conversa ja atribuida depois do dry-run.
  - redistribuicao de conversa atribuida pelo modulo quando o agente nao deu
    primeira resposta dentro do timeout;
  - bloqueio de redistribuicao quando a execucao real esta desligada;
  - bloqueio quando nao ha outro agente elegivel online;
  - ignorar conversas respondidas, reatribuidas manualmente ou ainda dentro do
    timeout;
  - uso do ultimo evento Ibsoft como novo marco para redistribuicoes futuras.

O job recorrente `Ibsoft::ConversationDistribution::WatchdogJob` fica registrado
no `config/schedule.yml` para rodar a cada minuto, mas retorna sem acao enquanto
`IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED` nao estiver ativo. O runner varre
apenas contas com politica Ibsoft ativa, exceto em execucao especifica por
`account_id`.

## Redistribuicao por falta de primeira resposta

O watchdog executa uma segunda fase privada para conversas que ja foram
atribuidas pelo modulo Ibsoft, mas continuam sem primeira resposta humana.

Essa redistribuicao nao usa callback em `Conversation` e nao altera o Assignment
V2. A fonte de verdade e o log privado
`ibsoft_conversation_distribution_event_logs`.

Uma conversa so entra nessa etapa quando:

- esta aberta;
- possui agente atribuido;
- ainda nao tem `first_reply_created_at`;
- possui time definido;
- a atribuicao atual corresponde ao ultimo evento Ibsoft
  `assignment_completed` ou `redistribution_completed`;
- a politica efetiva esta ativa;
- `config.redistribution.enabled=true`;
- o tempo desde o ultimo evento Ibsoft passou de
  `config.redistribution.first_response_timeout_minutes`.

Esse desenho evita interferir em:

- atribuicoes manuais diretas para agente;
- conversas manualmente reatribuidas depois da distribuicao Ibsoft;
- conversas ja respondidas por humano;
- conversas que ainda nao atingiram o timeout configurado.

Com execucao real desligada, candidatas vencidas geram
`redistribution_skipped` com reason `real_assignment_disabled` e nao alteram a
conversa.

Com execucao real ligada:

- o executor escolhe outro agente online pertencente ao canal e ao time;
- o agente atual e excluido da rodada;
- a conversa e capturada com `FOR UPDATE SKIP LOCKED`;
- o executor confirma que o ultimo evento Ibsoft ainda e o mesmo antes de
  atualizar;
- a redistribuicao grava `redistribution_completed` com
  `previous_assignee_id`, `new_assignee_id`, timeout e evento gatilho;
- se nao houver outro agente elegivel, grava `redistribution_skipped` com
  `no_available_agent`;
- se a conversa mudar durante a rodada, grava `redistribution_skipped` com
  `candidate_already_changed`.

Casos passivos como politica desativada, redistribuicao desativada ou timeout
nao atingido aparecem apenas no resumo da rodada e nao geram eventos repetidos.

Para ativacao gradual em producao:

1. manter `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false` e validar pelo
   endpoint administrativo;
2. ativar `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=true` com
   `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false` se for
   desejado observar logs sem atribuir;
3. ativar `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true`
   apenas depois de validar politicas, horarios e volume.

## Pontos de acoplamento no Chatwoot original

Neste incremento inicial, os pontos de acoplamento sao:

- `config/routes.rb`: registro das rotas API do namespace
  `ibsoft/conversation_distribution`.
- `config/schedule.yml`: registro do cron privado
  `ibsoft_conversation_distribution_watchdog_job`, protegido por flag.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`:
  adiciona a secao Ibsoft de distribuicao na configuracao do canal.
- `app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue`: adiciona
  um botao discreto na linha do time para abrir o modal Ibsoft de distribuicao.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: adicionam
  textos da interface do modulo.
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`:
  ponto pequeno para marcar origem Ibsoft quando uma conversa e atribuida a um
  time via API/UI.
- `app/services/action_service.rb`: ponto pequeno para marcar origem Ibsoft
  quando uma automacao, macro ou acao de sistema atribui a conversa a um time.

Nenhum callback de conversa, status de agente, Assignment V2 ou ActionCable foi
alterado nesta fase. A unica escrita nova em conversa e o marcador
`additional_attributes.ibsoft_distribution_source` durante atribuicao a time,
sem executar distribuicao. A atribuicao real so acontece pelo endpoint
administrativo `POST /executions` quando a flag global de seguranca estiver
explicitamente ligada.

## Proximas fases planejadas

1. Criar dashboard de supervisor.
2. Expandir a tela de horario proprio do time com grade semanal quando a regra
   `business_hours.mode=custom` for ativada para execucao real.

## Validacao recomendada

- `bundle exec rspec spec/models/ibsoft/conversation_distribution spec/services/ibsoft/conversation_distribution spec/requests/api/v1/accounts/ibsoft/conversation_distribution`
- `bundle exec rspec spec/jobs/ibsoft/conversation_distribution/watchdog_job_spec.rb spec/configs/schedule_spec.rb`
- validar build/lint dos arquivos em
  `app/javascript/dashboard/ibsoft/conversationDistribution/`;
- validar manualmente CRUD de politica por canal e por time;
- validar que agentes comuns nao conseguem alterar politicas;
- validar que a politica efetiva respeita a precedencia time > canal > padrao.
