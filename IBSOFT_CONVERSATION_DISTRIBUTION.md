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

## Semantica de propriedade e fila humana

A fila humana deve conter somente conversas sem qualquer responsavel:
`assignee_id IS NULL` e `assignee_agent_bot_id IS NULL`. Uma conversa com
`assignee_agent_bot_id` pertence ao `AgentBot`, mesmo que nao possua agente
humano, e portanto nao pode ser contada, listada, distribuida ou assumida como
conversa nao atribuida.

O escopo nativo `Conversation.unassigned` e a fonte de verdade para a fila
humana. O escopo `Conversation.assigned` inclui tanto agentes humanos quanto
`AgentBot`. Finders, contadores, filtros, permissoes, nao lidos e services de
atribuicao devem usar esses escopos em vez de inferir propriedade somente por
`assignee_id`.

Quando a entrega de um webhook ao bot falha de forma definitiva, o Chatwoot usa
`conversation.bot_handoff!`: a conversa e aberta, a propriedade do bot e limpa
e ela passa a ser uma candidata real da fila humana. Se a configuracao
`keep_pending_on_bot_failure` estiver ativa, a conversa continua pendente e sob
responsabilidade do bot, sem aparecer na fila.

Essa separacao evita divergencia entre o contador e a lista da fila. A
divergencia anterior fazia o frontend pedir paginas adicionais continuamente
quando o backend contava conversas do bot como nao atribuidas, mas o frontend
nao as renderizava.

## Estrutura inicial

Backend isolado:

- `app/models/ibsoft/conversation_distribution/channel_policy.rb`
- `app/models/ibsoft/conversation_distribution/team_policy.rb`
- `app/models/ibsoft/conversation_distribution/automation_handoff_policy.rb`
- `app/models/ibsoft/conversation_distribution/event_log.rb`
- `app/models/ibsoft/conversation_distribution/configuration.rb`
- `app/services/ibsoft/conversation_distribution/configuration_validator.rb`
- `app/services/ibsoft/conversation_distribution/business_hours_break_validator.rb`
- `app/services/ibsoft/conversation_distribution/unavailability_config_validator.rb`
- `app/services/ibsoft/conversation_distribution/unavailability_config_normalizer.rb`
- `app/services/ibsoft/conversation_distribution/candidate_finder.rb`
- `app/services/ibsoft/conversation_distribution/automation_handoff_candidate_finder.rb`
- `app/services/ibsoft/conversation_distribution/automation_handoff_executor.rb`
- `app/services/ibsoft/conversation_distribution/source_resolver.rb`
- `app/services/ibsoft/conversation_distribution/source_marker.rb`
- `app/services/ibsoft/conversation_distribution/queue_return_marker.rb`
- `app/services/ibsoft/conversation_distribution/queue_return_service.rb`
- `app/services/ibsoft/conversation_distribution/manual_assignment_service.rb`
- `app/services/ibsoft/conversation_distribution/team_transfer_preparer.rb`
- `app/services/ibsoft/conversation_distribution/manual_transfer_permission.rb`
- `app/services/ibsoft/conversation_distribution/scoped_watchdog_enqueuer.rb`
- `app/services/ibsoft/conversation_distribution/candidate_evaluator.rb`
- `app/services/ibsoft/conversation_distribution/dry_run_preview.rb`
- `app/services/ibsoft/conversation_distribution/execution_config.rb`
- `app/services/ibsoft/conversation_distribution/decision_resolver.rb`
- `app/services/ibsoft/conversation_distribution/unavailability_config.rb`
- `app/services/ibsoft/conversation_distribution/decision_action_executor.rb`
- `app/services/ibsoft/conversation_distribution/event_logger.rb`
- `app/services/ibsoft/conversation_distribution/assignment_executor.rb`
- `app/services/ibsoft/conversation_distribution/assignment_agent_selector.rb`
- `app/services/ibsoft/conversation_distribution/agent_capacity_evaluator.rb`
- `app/services/ibsoft/conversation_distribution/agent_capacity_guard.rb`
- `app/services/ibsoft/conversation_distribution/assignment_rate_limiter.rb`
- `app/services/ibsoft/conversation_distribution/assignment_rate_tracker.rb`
- `app/services/ibsoft/conversation_distribution/assignment_confirmation_notifier.rb`
- `app/services/ibsoft/conversation_distribution/assignment_round_limiter.rb`
- `app/services/ibsoft/conversation_distribution/assignment_summary_builder.rb`
- `app/services/ibsoft/conversation_distribution/agent_assignment_candidate_builder.rb`
- `app/services/ibsoft/conversation_distribution/agent_assignment_preview.rb`
- `app/services/ibsoft/conversation_distribution/agent_assignment_request_guard.rb`
- `app/services/ibsoft/conversation_distribution/agent_assignment_claimer.rb`
- `app/services/ibsoft/conversation_distribution/agent_entry_assignment_policy.rb`
- `app/services/ibsoft/conversation_distribution/agent_stabilization_filter.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_candidate_finder.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_executor.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_policy.rb`
- `app/services/ibsoft/conversation_distribution/redistribution_result_builder.rb`
- `app/services/ibsoft/conversation_distribution/previous_assignee_participation_cleanup.rb`
- `app/services/ibsoft/conversation_distribution/watchdog_runner.rb`
- `app/services/ibsoft/conversation_distribution/effective_policy_resolver.rb`
- `app/services/ibsoft/conversation_distribution/supervisor_alert_finder.rb`
- `app/services/ibsoft/conversation_distribution/event_log_finder.rb`
- `app/services/ibsoft/conversation_distribution/supervisor_permission.rb`
- `app/jobs/ibsoft/conversation_distribution/watchdog_job.rb`
- `app/controllers/api/v1/accounts/ibsoft/conversation_distribution/`

Frontend isolado:

- `app/javascript/dashboard/ibsoft/conversationDistribution/api.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/manualAssignmentAvailability.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/manualAssignmentStateSync.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/policyDefaults.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/DistributionPolicyForm.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/TeamDistributionSettingsModal.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/AgentAssignmentPrompt.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/TransferConversationContextMenuAction.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/TransferToAgentDialog.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/QueueReturnDialog.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/PolicyBusinessHourDay.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/views/SupervisorDashboard.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/views/EventLogsDashboard.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/helpers/assignmentAudioNotifications.js`
- `app/javascript/dashboard/ibsoft/conversationDistribution/routes.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/components/AutomationHandoffPolicyModal.vue`
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`
  consome o modal nos cards privados de canais de comunicacao.

Banco de dados:

- `ibsoft_conversation_distribution_policies`
- `ibsoft_conversation_distribution_channel_policies`
- `ibsoft_conversation_distribution_team_policies`
- `ibsoft_conversation_distribution_automation_handoff_policies`
- `ibsoft_conversation_distribution_event_logs`

## Politicas

### Catalogo de politicas nomeadas

As regras operacionais ficam em politicas nomeadas reutilizaveis, na tabela
`ibsoft_conversation_distribution_policies`. Cada politica possui nome,
`enabled` e `config`.

Uma politica nomeada define:

- ativar/desativar distribuicao;
- fontes elegiveis;
- ordem de atribuicao (`round_robin` ou `balanced`);
- prioridade de atendimento (`longest_waiting` ou `earliest_created`);
- maximo operacional opcional por rodada de distribuicao automatica;
- modo de limite de capacidade por agente:
  - `open_conversations`: maximo de atendimentos abertos simultaneos;
  - `assignment_window`: maximo de novas atribuicoes dentro de uma janela;
- excecoes para a capacidade simultanea:
  - etiquetas que nao ocupam capacidade;
  - atendimentos aguardando resposta do cliente por mais de X minutos;
- redistribuicao por falta de primeira resposta;
- confirmacao automatica opcional quando o atendimento for atribuido a um
  agente online pelo motor Ibsoft;
- comportamento por motivo de indisponibilidade:
  - `unavailability.no_available_agent`: quando esta dentro do horario, mas
    nenhum agente pode receber o atendimento;
  - `unavailability.outside_business_hours`: quando o atendimento esta fora do
    horario do canal ou da politica do time;
- horario/fallback padrao;
- alerta de supervisor.

Editar uma politica nomeada afeta todos os canais e times vinculados a ela. A UI
deve deixar isso claro para evitar alteracoes acidentais em operacoes
compartilhadas.

O cadastro e edicao dessas politicas ficam centralizados em Configuracoes do
ChatHub. A tela deve seguir o fluxo operacional padrao do Assignment V2: listar
politicas em cards de largura total, editar a politica em modal, remover uma
politica pelo card e criar nova politica apenas pelo botao de adicionar. As
telas de canal de comunicacao e time devem exibir apenas o vinculo com uma
politica existente, sem editar a regra completa naquele contexto.

As capacidades de atribuicao seguem os conceitos do Assignment V2, mas rodam em
services proprios Ibsoft:

- `AssignmentAgentSelector`: escolhe agente por rodizio ou por carga
  equilibrada no canal/departamento;
- `AgentCapacityEvaluator`: quando `assignment_limit_mode=open_conversations`,
  conta apenas conversas abertas atribuidas ao agente na conta, ignorando
  etiquetas configuradas e conversas em que a ultima mensagem publica foi do
  agente ha mais que o prazo configurado;
- `AgentCapacityGuard`: adquire um advisory lock transacional do PostgreSQL por
  conta e agente, revalida a capacidade dentro da transacao e mantem o lock ate
  concluir a atribuicao ou redistribuicao. Se outra execucao consumir a vaga, o
  executor tenta o proximo agente elegivel;
- `AssignmentRateLimiter`: limita quantas atribuicoes o agente pode receber na
  janela configurada quando `assignment_limit_mode=assignment_window`;
- `AssignmentRoundLimiter`: limita a quantidade total por rodada apenas quando
  `distribution.max_assignments_per_round_enabled=true`;
- `CandidatePrioritizer`: reordena candidatos conforme a prioridade da politica
  antes de aplicar o limite da execucao.

O padrao Ibsoft preserva o comportamento historico do modulo e usa
`conversation_priority=longest_waiting`. Uma politica pode alterar para
`earliest_created` quando a operacao quiser seguir a ordem de criacao.

No modo `open_conversations`, o limite simultaneo e garantido entre processos,
containers e instancias em autoscaling porque a decisao final nao depende do
lock de um worker especifico. O PostgreSQL serializa as tentativas concorrentes
do mesmo agente, e a contagem e repetida depois da aquisicao do lock. A garantia
abrange tanto a distribuicao inicial quanto a redistribuicao automatica. Uma
atribuicao manual ainda pode ultrapassar deliberadamente o limite, pois o limite
e uma regra dos motores automaticos.

O bloco `assignment_confirmation` controla a mensagem automatica enviada quando
o motor Ibsoft atribui uma conversa a um agente:

- `enabled`: ativa ou desativa o envio;
- `message`: texto da mensagem, com suporte a `{{agent.name}}`,
  `{{agent.email}}`, `{{team.name}}` e `{{account.name}}`;
- `only_before_first_reply`: quando ativo, evita enviar a confirmacao se a
  conversa ja teve primeira resposta humana.

A mensagem e criada como `template`, publica e sem remetente humano, para nao
contar como primeira resposta do agente. O service
`AssignmentConfirmationNotifier` grava um registro em
`conversation.additional_attributes` para evitar duplicidade em reprocessamento.

As mensagens operacionais internas do motor Ibsoft sao criadas como
`message_type=activity` pelo service `ActivityMessageNotifier`. Elas registram
atribuicao automatica, aceite manual pelo modal pos-login e redistribuicao por
timeout, usando textos Rails i18n em
`config/locales/ibsoft_conversation_distribution.*.yml`.

O campo legado `unavailable` continua aceito para compatibilidade com politicas
criadas antes da separacao por motivo. Quando uma politica antiga possui apenas
`unavailable`, o normalizador copia essa configuracao para
`unavailability.no_available_agent` e `unavailability.outside_business_hours`.
Novas politicas devem gravar explicitamente o bloco `unavailability`, mantendo
mensagens e fallbacks separados para evitar ambiguidade operacional.

### Canal de comunicacao e time

Canal e time nao devem guardar copias independentes da regra sempre que houver
alternativa. Eles funcionam como vinculos:

- `ibsoft_conversation_distribution_channel_policies` vincula um canal a uma
  politica nomeada padrao;
- `ibsoft_conversation_distribution_team_policies` vincula um time a uma
  politica nomeada quando `override_channel_policy=true`;
- essas tabelas nao guardam mais `enabled` nem `config`; toda regra operacional
  fica exclusivamente em `ibsoft_conversation_distribution_policies`;
- `db/migrate/20260703120000_remove_legacy_ibsoft_distribution_link_config.rb`
  converte configuracoes antigas de canal/time em politicas nomeadas antes de
  remover as colunas legadas.

A precedencia planejada e:

1. politica nomeada vinculada ao time, quando `override_channel_policy=true`;
2. politica nomeada vinculada ao canal de comunicacao;
3. padrao global Ibsoft, desativado.

Um vinculo sem `distribution_policy_id` e considerado desativado. Isso nao e
fallback de regra: e ausencia explicita de politica aplicavel naquele ponto.

### Politica de automacoes paradas por canal

A tabela `ibsoft_conversation_distribution_automation_handoff_policies`
configura, por canal de comunicacao, o que fazer quando uma conversa fica presa
na automacao.

Essa politica e separada da politica nomeada de distribuicao porque resolve um
problema anterior ao atendimento humano: retirar conversas de `pending` quando a
automacao ficou parada. Depois que a conversa e encaminhada para um time humano,
o fluxo normal de distribuicao Ibsoft passa a decidir se atribui a um agente,
aguarda, envia mensagem de indisponibilidade ou aplica fallback conforme a
politica de distribuicao vinculada ao canal/time.

Campos principais:

- `enabled`: ativa a verificacao no canal;
- `stale_after_minutes`: tempo maximo que a conversa pode ficar parada na
  automacao;
- `target_team_id`: time humano que recebera a conversa;
- `customer_message_enabled` e `customer_message`: mensagem publica opcional ao
  cliente.

O evento interno na conversa e obrigatorio e usa Rails i18n. A mensagem ao
cliente e opcional, publica e criada como `message_type=template`, para nao
contar como primeira resposta humana.

Uma conversa so e candidata quando:

- esta com `status=pending`;
- nao possui `assignee_id`;
- ainda nao possui `first_reply_created_at`;
- pertence a um canal com politica ativa;
- `last_activity_at` e mais antigo que `stale_after_minutes`;
- ha sinal de automacao ativa: bot ativo no canal, `assignee_agent_bot_id` ou
  historico de mensagem com `sender_type=AgentBot`;
- nao existe evento `automation_handoff_completed` criado depois da ultima
  atividade da conversa.

Essa busca e uma excecao intencional ao escopo `Conversation.unassigned`: ela
analisa conversas ainda pertencentes ao bot justamente para executar a politica
de automacao parada. Somente depois do `AutomationHandoffExecutor` limpar
`assignee_agent_bot_id` a conversa entra na fila humana e pode seguir para a
distribuicao normal.

O service `AutomationHandoffExecutor` usa `FOR UPDATE SKIP LOCKED` para evitar
processamento concorrente. Quando
`IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`, ele apenas
registra `automation_handoff_skipped` com motivo `real_assignment_disabled`.
Quando a execucao real esta ativa, ele:

- abre a conversa;
- move para o time alvo;
- limpa `assignee_id` e `assignee_agent_bot_id`;
- preserva `waiting_since` quando ja existir;
- marca `additional_attributes.ibsoft_distribution_source=system_team_transfer`
  e `ibsoft_distribution_source_reason=automation_stalled`;
- registra `automation_handoff_completed` na auditoria.

O horario fica dentro da politica nomeada. O campo `business_hours.mode` aceita:

- `inherit_channel`: usa o horario do canal;
- `custom`: usa horario proprio do time;
- `always_available`: considera o time sempre disponivel.

Quando `custom` e selecionado, a UI privada grava `business_hours.timezone` e
`business_hours.schedule` no mesmo formato de `working_hours` do Chatwoot
(`day_of_week`, `closed_all_day`, `open_all_day`, `open_hour`,
`open_minutes`, `close_hour`, `close_minutes`). O padrao inicial e segunda a
sexta, 09:00-17:00, com fim de semana fechado.

Politicas com horario proprio tambem podem gravar intervalos em
`business_hours.breaks`, no formato `day_of_week`, `start_hour`,
`start_minutes`, `end_hour` e `end_minutes`. Esses intervalos usam a mesma
semantica dos intervalos de canais: o inicio e inclusivo e o fim e exclusivo.
Durante um intervalo, o motor trata a conversa como
`outside_business_hours` e aplica a acao configurada para esse motivo.

## Pre-requisito operacional para ativacao

Para evitar concorrencia entre motores de atribuicao, a distribuicao Ibsoft deve
ser ativada apenas depois de desligar as atribuicoes nativas equivalentes:

- autoatribuicao do canal de comunicacao;
- politica nativa/Assignment V2 vinculada ao canal, quando estiver ativa;
- autoatribuicao do time (`team.allow_auto_assign`).

As telas Ibsoft exibem um alerta quando detectam essas configuracoes nativas
ainda ativas. O alerta nao bloqueia o salvamento, mas indica que a politica
Ibsoft ainda nao deve ser considerada dona exclusiva da distribuicao.

## API inicial

Todas as rotas ficam sob:

`/api/v1/accounts/:account_id/ibsoft/conversation_distribution`

Rotas:

- `GET /policies`
- `GET /policies/:id`
- `POST /policies`
- `PATCH /policies/:id`
- `DELETE /policies/:id`
- `GET /automation_handoff_policies/:inbox_id`
- `PATCH /automation_handoff_policies/:inbox_id`
- `GET /inbox_policies/:inbox_id`
- `PATCH /inbox_policies/:inbox_id`
- `GET /team_policies/:team_id`
- `PATCH /team_policies/:team_id`
- `GET /effective_policy?inbox_id=:inbox_id&team_id=:team_id`
- `GET /dry_runs?inbox_id=:inbox_id&team_id=:team_id&limit=:limit`
- `POST /executions`
- `GET /supervisor_alerts?inbox_id=:inbox_id&team_id=:team_id&limit=:limit`
- `GET /event_logs?event_type=:event_type&reason=:reason&page=:page&limit=:limit`
- `GET /agent_assignments?limit=:limit`
- `POST /agent_assignments/claim`
- `POST /conversations/:conversation_id/return_to_queue`

As rotas de configuracao de politicas, dry-run e execucao continuam
administrativas. As rotas somente leitura de `supervisor_alerts` e `event_logs`
aceitam administradores ou usuarios com perfil Ibsoft que contenha a permissao
`ibsoft_conversation_distribution_supervise`.

O papel privado de supervisor nao altera o `AccountUser.role` do Chatwoot. A
permissao adicional exposta ao dashboard e
`ibsoft_conversation_distribution_supervise`, calculada por
`Ibsoft::ConversationDistribution::SupervisorPermission`.

## Dry-run de elegibilidade

O endpoint `dry_runs` monta uma pre-visualizacao somente leitura das conversas
que seriam candidatas a distribuicao.

Filtros iniciais:

- conversa `open`;
- sem agente humano atribuido (`assignee_id` vazio);
- com time definido;
- sem primeira resposta humana (`first_reply_created_at` vazio);
- respeitando `inbox_id`, `team_id` e `limit` quando enviados.

A unica excecao para a primeira resposta e uma conversa devolvida
explicitamente a fila pelo proprio agente responsavel. Nesse caso,
`first_reply_created_at` e preservado e a elegibilidade temporaria e identificada
por `additional_attributes.ibsoft_distribution_source_reason =
agent_returned_to_queue`.

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
  um time;
- `system_team_transfer`: marcada quando uma automacao ou `AgentBot` transfere
  a conversa para um time.

Conversas sem marcador explicito e sem evento de handoff do bot retornam origem
desconhecida e nao sao distribuidas automaticamente. Essa decisao evita que uma
conversa apenas aberta, sem agente e com time seja tratada como transferencia
humana por inferencia ampla.

Quando um usuario transfere uma conversa para um departamento pela UI, o
dashboard usa o endpoint privado
`POST /conversations/:conversation_id/manual_assignment`. O
`ManualAssignmentService` bloqueia conversas encerradas, abre conversas
pendentes ou adiadas e devolve ao frontend o estado final da conversa. A
operacao e protegida por lock no registro e valida agentes e departamentos no
escopo da conta. Identificadores malformados sao rejeitados sem serem
interpretados como desatribuicao. Agentes de destino precisam estar entre os
agentes atribuiveis do canal, preservando a regra da API nativa; administradores
da conta continuam atribuiveis conforme o comportamento do Chatwoot.

Na atribuicao direta a um agente, o responsavel escolhido e aplicado sem
colocar a conversa na distribuicao automatica. Notificacoes de atencao e a
participacao obsoleta do agente anterior sao removidas quando o responsavel
muda. A mesma limpeza ocorre quando a transferencia para departamento remove o
agente atual. Na atribuicao a departamento, o
`TeamTransferPreparer` remove o agente atual antes da troca somente quando:

- a politica efetiva do time/canal esta habilitada e aceita
  `manual_team_transfer`;
- o job e a atribuicao real Ibsoft estao habilitados;
- a autoatribuicao nativa do time esta desabilitada;
- o departamento de destino e diferente do atual; ou
- a conversa esta no mesmo departamento, mas sem agente humano responsavel.

Quando preparada para distribuicao, a conversa e gravada como aberta, preserva
`waiting_since` existente, remove agente humano e bot, e agenda uma rodada do
`WatchdogJob` limitada a conta, canal e departamento afetados. Se
`waiting_since` ainda estiver vazio, ele e inicializado no momento da
transferencia. Isso evita aguardar o cron global para distribuir a conversa.
Se o enqueue imediato falhar por indisponibilidade transitoria do Sidekiq ou do
Redis, a transferencia confirmada no banco continua sendo respondida como
sucesso, a falha e registrada no log e o watchdog periodico pode recuperar a
conversa marcada quando a infraestrutura voltar.

Selecionar novamente o mesmo departamento preserva o agente humano atual. Se a
conversa estiver sem agente ou com bot, a mesma selecao pode encaminha-la para a
fila privada. Fora das condicoes da politica, o `ManualAssignmentService` ainda
abre e transfere a conversa, mas preserva o responsavel e nao agenda a
distribuicao, evitando efeitos automaticos em modo seguro. Transferencias reais
continuam registrando a origem mesmo em modo seguro, para preservar o contrato
com automacoes, bots e consumidores da API nativa.

Conversas `resolved` mantem os seletores visiveis, mas desabilitados, na barra
lateral e no menu contextual. O backend privado repete essa validacao sob lock
e responde `manual_assignment_resolved`, de modo que uma chamada direta nao
contorne a protecao visual. Acoes em massa, macros, automacoes e consumidores da
API nativa continuam no fluxo original do Chatwoot; esta integracao privada se
aplica as atribuicoes individuais do dashboard.

Quando ja existe agente humano responsavel, os controles individuais de
transferencia ficam disponiveis somente para o proprio responsavel ou para um
administrador da conta. Outros agentes veem os controles desabilitados e o
backend repete a verificacao sob lock por meio de
`ManualTransferPermission`. Conversas sem responsavel humano, inclusive as que
estao com bot, continuam transferiveis por agentes com acesso a conversa. O
frontend considera o formato nativo `meta.assignee_type=AgentBot`, e o backend
continua sendo a autoridade final sob lock.

### Transferencia manual pelo menu de contexto

O menu de contexto da conversa apresenta uma unica acao
`Transferir atendimento`, com duas opcoes:

- `Para um agente`: abre um modal com os agentes disponiveis no canal e aplica
  o responsavel escolhido sem colocar a conversa na distribuicao automatica;
- `Para a fila de um departamento`: abre um modal com os departamentos da
  conta, remove o responsavel atual e entrega a conversa para a fila privada do
  departamento escolhido.

No backend, a validacao do agente consulta somente o `AccountUser` solicitado
e verifica a associacao ao canal com `EXISTS`. Administradores da conta mantem
o comportamento nativo de poder receber a conversa sem associacao explicita ao
canal. A transferencia nao materializa a lista completa de agentes e, por isso,
seu custo nao cresce linearmente com o total de usuarios da conta.
O departamento atual nao limita a atribuicao direta: um agente atribuivel ao
canal pode receber a conversa mesmo pertencendo a outro departamento. Nesse
caso, o departamento da conversa e preservado; sua troca exige a opcao
especifica de transferencia para fila.

A transferencia para fila:

- aceita conversas abertas, pendentes ou adiadas e as deixa abertas;
- rejeita conversas encerradas no frontend e novamente no backend;
- exige distribuicao e atribuicao real habilitadas;
- exige politica efetiva ativa que aceite `manual_team_transfer`;
- exige autoatribuicao nativa desabilitada no departamento de destino;
- remove agente humano e bot atribuidos;
- atualiza `waiting_since` para o momento da nova entrada na fila;
- preserva `first_reply_created_at` e todo o historico da conversa;
- remove notificacoes de atencao e participacao obsoletas do agente anterior;
- registra `queue_returned/agent_returned_to_queue` na auditoria;
- cria mensagem interna de atividade informando agente e departamento.

Depois da gravacao, o endpoint agenda imediatamente uma rodada do
`WatchdogJob` limitada a conta, canal e departamento. Isso vale inclusive para
o departamento atual e evita esperar o cron global para redistribuir a
conversa.

Se a conversa ja estiver aberta, sem agente humano ou bot e aguardando na fila
do departamento selecionado, a operacao e recusada como idempotente. O modal
desabilita a confirmacao para esse departamento e o backend preserva
`waiting_since`, auditoria e jobs; ainda e possivel escolher outro departamento.

Ao confirmar um modal, conversa e destino sao capturados antes da chamada. Uma
mudanca de selecao, reciclagem da linha virtual ou duplo clique durante a
requisicao nao altera o alvo em andamento. A sincronizacao do store usa a
resposta final da API e e ignorada com seguranca se a conversa ja tiver saido
da lista, evitando transformar uma operacao concluida no backend em falso erro
visual.

A auto-desatribuicao pelo seletor lateral continua usando o mesmo service em
modo restrito: exige conversa aberta e atribuida ao proprio usuario. Se a
distribuicao privada estiver indisponivel, o fluxo nativo de desatribuicao
continua funcionando sem marcar a conversa como candidata. Selecionar
novamente o mesmo departamento no seletor de times nao desatribui o agente.

O marcador `agent_returned_to_queue` e temporario. O
`AssignmentExecutor` o remove atomicamente quando atribui a conversa novamente,
evitando que uma desatribuicao futura seja considerada elegivel por um marcador
antigo. O agente anterior pode ser escolhido novamente se continuar online e
for o melhor candidato segundo a politica.

## Execucao de atribuicao

O endpoint `POST /executions` executa o mesmo fluxo do `dry-run`, mas registra
eventos de auditoria em `ibsoft_conversation_distribution_event_logs`.

Por padrao, a execucao real fica bloqueada pela flag global:

`IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`

O job automatico tambem fica bloqueado por uma flag separada:

`IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false`

O limite por rodada do job pode ser ajustado por:

`IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT=50`

Esse valor e apenas um teto tecnico de varredura por execucao, usado para
evitar consultas grandes demais. Ele nao deve ser tratado como regra
operacional de distribuicao. O limite operacional por canal/time vem da
politica efetiva em `config.distribution.max_assignments_per_round`.

O watchdog usa um lock distribuido em Redis para evitar duas rodadas
concorrentes do mesmo escopo (`account_id`, `inbox_id`, `team_id`). O TTL
padrao do lock e 5 minutos e pode ser ajustado por:

`IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS=300`

Se uma rodada ainda estiver em execucao, a seguinte retorna `locked=true` e nao
instancia os executores de atribuicao/redistribuicao.

Com a flag desligada:

- nenhuma conversa recebe `assignee_id`;
- cada candidata elegivel gera log `assignment_skipped` com reason
  `real_assignment_disabled`;
- o payload retorna resumo por motivo.

Eventos repetidos de `assignment_skipped` e `redistribution_skipped` sao
deduplicados por uma janela curta para evitar crescimento artificial da tabela
de auditoria em ciclos recorrentes. A janela padrao e 15 minutos e pode ser
ajustada por:

`IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS=900`

A tabela de auditoria possui indices compostos para os caminhos criticos de
leitura: deduplicacao recente, busca do ultimo evento por conversa e filtros do
dashboard de logs. Esses indices ficam na migration
`20260703123000_add_ibsoft_distribution_event_log_performance_indexes.rb`.

Com a flag ligada:

- o `DecisionResolver` classifica a conversa antes de tentar atribuir;
- a decisao considera elegibilidade, politica efetiva e horario de atendimento;
- o `AssignmentRoundLimiter` limita a quantidade de conversas elegiveis
  processadas por par canal/time usando
  `config.distribution.max_assignments_per_round` da politica efetiva;
- conversas elegiveis acima desse limite ficam como `ignored` com reason
  `round_limit_reached`, sem gerar evento de falha;
- o `DecisionActionExecutor` executa efeitos colaterais configurados para
  indisponibilidade, com idempotencia por conversa;
- o executor considera apenas candidatas elegiveis pela politica efetiva;
- seleciona agente online pertencente ao time e ao canal de comunicacao;
- nao depende de `team.allow_auto_assign`, pois essa flag controla a
  autoatribuicao nativa do Chatwoot e pode ficar desligada quando a distribuicao
  Ibsoft for responsavel pela regra;
- respeita `member_ids_with_assignment_capacity`, incluindo filtros Enterprise
  quando presentes;
- aplica `AgentStabilizationFilter` quando a janela global de estabilizacao
  pos-login esta ativa, evitando concentrar atribuicoes em um agente que acabou
  de voltar depois de muito tempo offline;
- captura a conversa com `FOR UPDATE SKIP LOCKED` antes de gravar assignee;
- grava `assignment_completed` com `new_assignee_id` quando atribui;
- cria mensagem de atividade `Atendimento atribuido automaticamente...` pelo
  `ActivityMessageNotifier`;
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
  - atribuicao mesmo quando o time desativou a autoatribuicao nativa do
    Chatwoot;
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

## Entrada do agente e assuncao de fila

O componente `AgentAssignmentPrompt` fica montado no dashboard autenticado e
consulta `GET /agent_assignments` quando o usuario atual fica online.

A API lista somente conversas:

- abertas;
- sem agente atribuido;
- sem primeira resposta humana;
- com time e canal dos quais o agente atual participa;
- elegiveis pela politica efetiva Ibsoft;
- dentro da decisao `assign` do `DecisionResolver`.

O payload marca como `required` as conversas obrigatorias ao entrar usando a
configuracao global por conta em `ibsoft_chathub_settings.config`, na secao
`agent_entry_assignment`. Essa regra calcula uma porcentagem sobre o total de
conversas disponiveis para o agente no momento do login, respeitando tambem um
minimo obrigatorio configuravel.

Essa configuracao e global porque um agente pode participar de varios times e
canais ao mesmo tempo. Prender a regra de entrada a um canal ou time criaria
ambiguidade operacional e poderia exigir que o mesmo usuario obedecesse a
limites conflitantes em uma unica entrada no sistema.

O frontend impede que o agente feche o prompt enquanto houver conversas
obrigatorias nao selecionadas quando
`agent_entry_assignment.block_close_when_required=true`. O backend repete a
validacao em
`AgentAssignmentRequestGuard`, entao uma chamada direta para a API tambem e
bloqueada quando:

- faltam conversas obrigatorias na solicitacao;
- uma conversa solicitada nao esta disponivel para o agente.

Nao ha limite manual de selecao no modal pos-login. Se o agente quiser assumir
mais do que o minimo obrigatorio, inclusive todos os atendimentos disponiveis, a
API deve permitir. O limite `max_assignments_per_round` continua valendo apenas
para a distribuicao automatica executada pelo watchdog.

O frontend do prompt solicita o teto tecnico de pre-visualizacao do backend
(`CandidateFinder::MAX_LIMIT`) para nao reduzir artificialmente a fila manual do
agente. Esse teto e uma protecao de carga da API, nao uma regra operacional de
distribuicao.

Quando `login_stabilization.enabled=true`, o watchdog usa a presenca capturada
em `ibsoft_chathub_agent_presence_states` para reduzir temporariamente novas
atribuicoes a agentes que acabaram de voltar depois de um periodo longo offline.
A regra e global por conta e usa:

- `offline_threshold_minutes`: quanto tempo offline caracteriza retorno critico;
- `window_minutes`: por quanto tempo apos login a janela fica ativa;
- `max_assignments_during_window`: teto de atribuicoes nesse periodo;
- `minimum_online_agents_to_disable`: numero de agentes online que desativa a
  restricao, para nao bloquear filas pequenas.

Quando `login_stabilization.enabled=false`, o watchdog nao sincroniza
`ibsoft_chathub_agent_presence_states` naquela conta. Isso evita varrer todos os
usuarios da conta em rodadas que nao precisam desse historico.

O `POST /agent_assignments/claim` atribui conversas ao usuario atual somente
quando:

- a flag `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true`;
- o usuario esta online na conta;
- o usuario pertence ao time e ao canal da conversa;
- a conversa continua aberta, sem assignee e sem primeira resposta humana;
- a politica efetiva continua elegivel e a decisao continua `assign`.

O claim usa `FOR UPDATE SKIP LOCKED` e grava eventos
`agent_claim_completed`/`agent_claim_skipped` na tabela privada de auditoria.

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
- a redistribuicao tambem nao depende de `team.allow_auto_assign`;
- o agente atual e excluido da rodada;
- a conversa e capturada com `FOR UPDATE SKIP LOCKED`;
- o executor confirma que o ultimo evento Ibsoft ainda e o mesmo antes de
  atualizar;
- a redistribuicao grava `redistribution_completed` com
  `previous_assignee_id`, `new_assignee_id`, timeout e evento gatilho;
- cria mensagem de atividade informando que o atendimento foi redistribuido
  automaticamente por falta de primeira resposta;
- `AttentionNotificationSync` remove notificacoes de responsabilidade do agente
  anterior, lidas ou nao, incluindo notificacoes de participante, preservando
  mencoes;
- `PreviousAssigneeParticipationCleanup` remove o agente anterior de
  `conversation_participants` depois de uma redistribuicao real, evitando que
  ele continue recebendo mensagens como participante. Isso vale apenas para
  redistribuicoes automaticas Ibsoft; transferencias manuais seguem o fluxo
  nativo do Chatwoot;
- se nao houver outro agente elegivel, grava `redistribution_skipped` com
  `no_available_agent`;
- se a conversa mudar durante a rodada, grava `redistribution_skipped` com
  `candidate_already_changed`.

Casos passivos como politica desativada, redistribuicao desativada ou timeout
nao atingido aparecem apenas no resumo da rodada e nao geram eventos repetidos.

## Dashboard de supervisor

O dashboard de supervisor e uma tela somente leitura para administradores e
supervisores Ibsoft acompanharem atendimentos parados.

Entrada frontend:

- rota `ibsoft_conversation_distribution_supervisor`;
- caminho `/app/accounts/:accountId/conversation-distribution/supervisor`;
- componente
  `app/javascript/dashboard/ibsoft/conversationDistribution/views/SupervisorDashboard.vue`.

Fonte de dados:

- `GET /api/v1/accounts/:account_id/ibsoft/conversation_distribution/supervisor_alerts`.

A API usa `SupervisorAlertFinder` e lista conversas:

- abertas;
- com time definido;
- sem primeira resposta humana;
- com `waiting_since` preenchido;
- cuja politica efetiva esta ativa;
- com `config.supervisor_alert.enabled=true`;
- cujo tempo de espera passou de
  `config.supervisor_alert.threshold_minutes`.

O painel nao altera conversas, nao cria logs e nao dispara atribuicoes. Ele
apenas calcula alertas atuais a partir do estado da conversa e da politica
efetiva. Os motivos iniciais sao:

- `unassigned_waiting`: conversa no time, sem agente atribuido;
- `assigned_without_first_reply`: conversa atribuida, mas sem primeira resposta
  humana.

A API tambem calcula severidade:

- `warning`: conversa acima do limite configurado;
- `critical`: conversa aguardando pelo menos o dobro do limite configurado.

O frontend permite filtrar os alertas carregados por motivo, severidade, time e
canal de comunicacao. Esses filtros sao somente visuais e nao alteram conversas.
A interface separa filtros e lista de alertas em areas distintas. A lista usa
rolagem propria para manter o contexto da pagina estavel mesmo com muitos
alertas.

O acesso de supervisao e configurado em `Perfis e permissoes`, nao por uma tela
propria de supervisores. A tabela legada
`ibsoft_conversation_distribution_supervisors` foi removida por migration de
limpeza.

## Auditoria de distribuicao

A tela de auditoria e somente leitura e usa a tabela privada
`ibsoft_conversation_distribution_event_logs`.

Entrada frontend:

- rota `ibsoft_conversation_distribution_event_logs`;
- caminho `/app/accounts/:accountId/conversation-distribution/events`;
- componente
  `app/javascript/dashboard/ibsoft/conversationDistribution/views/EventLogsDashboard.vue`.

Fonte de dados:

- `GET /api/v1/accounts/:account_id/ibsoft/conversation_distribution/event_logs`.

Filtros suportados pela API:

- `event_type`;
- `reason`;
- `conversation_id`;
- `inbox_id`;
- `team_id`;
- `previous_assignee_id`;
- `new_assignee_id`;
- `since`;
- `until`;
- `page`;
- `limit`.

O finder `EventLogFinder` consulta apenas eventos da conta atual, ordena por
data mais recente, aplica limite maximo e retorna metadados de paginacao. A tela
exibe o evento, motivo, conversa, contato, roteamento e agentes envolvidos. O ID
da conversa usa link direto para abrir o atendimento em nova aba. O filtro
`conversation_id` aceita o ID visivel exibido na UI do Chatwoot, inclusive com
prefixo `#`. Quando nao encontra conversa com esse `display_id` na conta, o
finder mantem compatibilidade tentando filtrar pelo ID interno gravado no evento.
Os tipos de evento sao apresentados apenas com rotulos traduzidos, sem expor
identificadores tecnicos como `redistribution_completed` na tabela. Ela nao
exibe JSON bruto nem coluna de detalhes na tabela; os metadados continuam
disponiveis na API para auditoria tecnica futura. Os filtros de canal de
comunicacao e departamento usam seletores alimentados pelas stores nativas de
inboxes e times do Chatwoot, sem endpoint proprio adicional. A paginacao fica no
rodape do
painel da lista, separada dos resultados. Ela nao altera conversas, politicas ou
logs.

A autorizacao da auditoria segue a mesma regra do dashboard de supervisor:
administradores ou usuarios registrados como supervisores Ibsoft na conta atual.

## Validacoes de configuracao

As politicas normalizam `config` usando `Configuration` e delegam validacoes a
`ConfigurationValidator`, ambos no namespace Ibsoft.

Validacoes protegidas no backend:

- chaves desconhecidas de `config` sao descartadas na normalizacao da politica,
  mantendo apenas as secoes suportadas pelo modulo;
- `unavailable.action` deve ser `wait`, `notify_customer` ou `fallback_team`;
- `notify_customer` exige mensagem;
- `fallback_team` exige time existente na mesma conta;
- `business_hours.mode` deve ser `inherit_channel`, `custom` ou
  `always_available`;
- horario customizado exige timezone valido e grade semanal;
- cada dia da grade deve ter `day_of_week` entre 0 e 6;
- um dia nao pode ser fechado e aberto 24h ao mesmo tempo;
- quando nao for fechado/24h, abertura e fechamento precisam existir, ser
  numericos e o fechamento precisa ser posterior a abertura;
- limites numericos de distribuicao, redistribuicao e alerta precisam ser
  inteiros positivos.

As chaves antigas/experimentais `distribution.strategy` e
`distribution.capacity_limit` nao fazem parte do contrato ativo. Os limites
operacionais suportados sao `distribution.assignment_limit_mode`,
`distribution.open_conversation_limit`,
`distribution.capacity_ignore_customer_waiting_enabled`,
`distribution.capacity_ignore_customer_waiting_minutes`,
`distribution.capacity_excluded_labels`,
`distribution.fair_distribution_limit`,
`distribution.fair_distribution_window` e
`distribution.max_assignments_per_round`.

Para ativacao gradual em producao:

1. manter `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=false` e validar pelo
   endpoint administrativo;
2. ativar `IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=true` com
   `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false` se for
   desejado observar logs sem atribuir;
3. ativar `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true`
   apenas depois de validar politicas, horarios e volume.

## Pontos de acoplamento no Chatwoot original

### Backport temporario de propriedade do AgentBot

Esta branch inclui antecipadamente a correcao oficial do Chatwoot
`f12529105bff8b16793c836bde5bfe1ba7e2f470` (`fix: align AgentBot ownership
with conversation counts (#15343)`). Ela corrige um comportamento nativo e nao
constitui regra de negocio privada Ibsoft.

O backport toca os escopos de `Conversation`, finder e filtros de conversa,
atribuicao automatica, automacoes, contadores de nao lidos, permissoes e os
fluxos Enterprise de chamadas. `lib/webhooks/trigger.rb` usa `bot_handoff!` na
falha definitiva do webhook. Os services privados de distribuicao foram
ajustados apenas para consumir a mesma semantica: distribuicao humana usa
`unassigned`; a politica de automacao parada continua buscando conversas
pendentes pertencentes ao bot.

O controle de acesso privado mantem essas conversas visiveis na automacao para
perfis que gerenciam a fila e possuem acesso ao canal. Essa permissao de
visualizacao nao transforma a conversa do `AgentBot` em fila humana. A
integracao frontend fica isolada em
`app/javascript/dashboard/ibsoft/accessControl/conversationVisibility.js` e so
e ativada pela permissao marcadora `ibsoft_access_role`. A
atribuicao automatica usa o bloqueio concorrente do commit oficial `0ad2780972`
para nao sobrescrever uma atribuicao concluida por outra execucao.

Ao sincronizar com uma versao upstream que ja contenha esse commit, reconciliar
ou remover o backport antes de resolver outros conflitos. Nao manter duas
implementacoes paralelas. Tambem revisar os acompanhamentos upstream conhecidos
para atualizacao de propriedade ao excluir um `AgentBot` (CW-7870) e para
atualizacao do contador no cabecalho de filtros salvos (CW-7899).

Esse ajuste nao cria tabela, migration, variavel de ambiente, callback ou job.

Neste incremento inicial, os pontos de acoplamento sao:

- `config/routes.rb`: registro das rotas API do namespace
  `ibsoft/conversation_distribution`.
- `config/schedule.yml`: registro do cron privado
  `ibsoft_conversation_distribution_watchdog_job`, protegido por flag.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`:
  teve o encaixe Ibsoft de distribuicao removido para manter as regras privadas
  do canal fora da tela nativa do Chatwoot.
- `app/javascript/dashboard/routes/dashboard/settings/teams/Index.vue`: adiciona
  um botao discreto na linha do time para abrir o modal Ibsoft de distribuicao.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend do painel de supervisao Ibsoft.
- `app/javascript/dashboard/routes/dashboard/Dashboard.vue`: monta o prompt
  privado de assuncao de fila do agente.
- `app/javascript/dashboard/helper/actionCable.js`: no evento nativo
  `assignee.changed`, delega para helper privado Ibsoft a decisao de tocar som
  quando a conversa passa a ser atribuida ao usuario atual.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: registra a
  Home ChatHub no menu lateral. O painel de supervisao continua em rota
  propria, mas o acesso visual fica dentro da Home para usuarios com permissao.
- `app/javascript/dashboard/ibsoft/conversationDistribution/views/SupervisorDashboard.vue`:
  mantem um retorno explicito para `ibsoft_chathub_home`, preservando o fluxo
  Home -> Supervisao -> Home sem depender do historico do navegador.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json` e
  `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: adicionam
  textos da interface do modulo.
- `app/views/api/v1/models/_user.json.jbuilder`: adiciona somente a permissao
  privada `ibsoft_conversation_distribution_supervise` ao payload de contas do
  usuario quando ele estiver registrado como supervisor Ibsoft. Esse ponto e
  necessario para o guard de rotas do dashboard reconhecer o acesso sem alterar
  `AccountUser.role`.
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`:
  ponto pequeno que delega ao `TeamTransferPreparer` a marcacao da origem e a
  preparacao da fila quando uma conversa e transferida para um time via API/UI,
  e ao `QueueReturnService` a auto-desatribuicao do agente quando a distribuicao
  privada estiver disponivel.
- `app/javascript/dashboard/store/modules/conversations/actions.js`: os pontos
  individuais `assignAgent` e `assignTeam` delegam ao endpoint privado e
  sincronizam agente, departamento, status e adiamento com o estado confirmado
  pelo backend por meio de `manualAssignmentStateSync.js`. Nao existe
  atualizacao otimista para estas operacoes, e o helper nao escreve em linhas
  que ja sairam do store.
- `app/javascript/dashboard/routes/dashboard/conversation/ConversationAction.vue`:
  mantem os seletores nativos e apenas os conecta ao fluxo privado, deixando-os
  desabilitados quando a conversa esta encerrada.
- `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue`:
  substitui os submenus individuais de agente e departamento por um unico
  ponto de conexao com `TransferConversationContextMenuAction`; o submenu fica
  visivel, mas desabilitado em conversas encerradas.
- `app/javascript/dashboard/composables/chatlist/useBulkActions.js`: somente a
  atribuicao individual originada pelo menu contextual delega ao fluxo privado;
  a operacao realmente em massa permanece na API nativa.
- `app/javascript/dashboard/composables/commands/useConversationHotKeys.js`:
  impede que atalhos executem atribuicao individual em conversa encerrada.
- `app/javascript/dashboard/components/ConversationItem.vue`: hospeda o
  `TransferToAgentDialog` e o `QueueReturnDialog` privados fora do menu de
  contexto. Esse ponto e necessario porque o menu nativo e desmontado ao perder
  o foco; manter os dialogs como filhos do menu faria os modais serem destruidos
  ao abrir. API, regra e sincronizacao do store continuam nos componentes
  privados.
- `app/services/action_service.rb`: ponto pequeno para marcar origem Ibsoft
  quando uma automacao, macro ou acao de sistema atribui a conversa a um time.

Nenhum callback de conversa, status de agente ou Assignment V2 foi alterado
nesta fase. O unico acoplamento em ActionCable e a chamada frontend ao helper
Ibsoft de som de atribuicao no evento `assignee.changed`; toda regra continua
isolada em `assignmentAudioNotifications.js`. A escrita privada na conversa e
limitada ao estado final da atribuicao, abertura, `waiting_since` quando ausente
e marcadores em `additional_attributes`. A atribuicao automatica pode ser
iniciada pelo endpoint administrativo `POST /executions`, pelo watchdog ou por
uma rodada escopada apos transferencia manual; todos dependem das flags globais
de job e atribuicao real.

## Proximas fases planejadas

1. Avaliar filtros server-side no dashboard de supervisor caso o volume de
   alertas por conta ultrapasse o limite de carregamento atual.

## Validacao recomendada

- `bundle exec rspec spec/finders/conversation_finder_spec.rb spec/models/conversation_spec.rb spec/lib/webhooks/trigger_spec.rb`
- `bundle exec rspec spec/services/auto_assignment spec/services/automation_rules/conditions_filter_service_spec.rb spec/services/conversations/unread_counts`
- `bundle exec rspec spec/enterprise/controllers/api/v1/accounts/whatsapp_calls_controller_spec.rb spec/enterprise/policies/conversation_policy_spec.rb spec/enterprise/services/enterprise/conversations/permission_filter_service_spec.rb spec/enterprise/services/voice spec/enterprise/services/whatsapp/call_service_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/store/modules/conversations/specs/helpers.spec.js app/javascript/dashboard/store/modules/conversations/helpers/specs/filterHelpers.spec.js app/javascript/dashboard/ibsoft/accessControl/specs/conversationVisibility.spec.js`

- `RAILS_ENV=test bundle exec rspec spec/models/ibsoft/conversation_distribution spec/services/ibsoft/conversation_distribution spec/requests/api/v1/accounts/ibsoft/conversation_distribution`
- `RAILS_ENV=test bundle exec rspec spec/jobs/ibsoft/conversation_distribution/watchdog_job_spec.rb spec/configs/schedule_spec.rb`
- `bundle exec rspec spec/models/ibsoft/conversation_distribution/automation_handoff_policy_spec.rb spec/services/ibsoft/conversation_distribution/automation_handoff_candidate_finder_spec.rb spec/services/ibsoft/conversation_distribution/automation_handoff_executor_spec.rb`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/conversationDistribution/specs/assignmentAudioNotifications.spec.js app/javascript/dashboard/helper/specs/actionCable.spec.js`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/conversationDistribution/specs/TransferConversationContextMenuAction.spec.js app/javascript/dashboard/ibsoft/conversationDistribution/specs/TransferToAgentDialog.spec.js`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/conversationDistribution/specs/QueueReturnDialog.spec.js`
- `pnpm exec vitest run app/javascript/dashboard/ibsoft/conversationDistribution/specs/manualAssignmentAvailability.spec.js app/javascript/dashboard/ibsoft/conversationDistribution/specs/manualAssignmentControls.spec.js app/javascript/dashboard/ibsoft/conversationDistribution/specs/manualAssignmentStateSync.spec.js app/javascript/dashboard/store/modules/specs/conversations/actions.spec.js`
- validar atribuicao individual de agente e departamento em conversas abertas,
  pendentes, adiadas e encerradas;
- validar transferencia para agente e para a fila do mesmo ou de outro
  departamento;
- validar que a conversa respondida preserva `first_reply_created_at` e volta a
  ser distribuida;
- validar build/lint dos arquivos em
  `app/javascript/dashboard/ibsoft/conversationDistribution/`;
- validar manualmente CRUD de politica por canal e por time;
- validar que agentes comuns nao conseguem alterar politicas;
- validar que a politica efetiva respeita a precedencia time > canal > padrao.
