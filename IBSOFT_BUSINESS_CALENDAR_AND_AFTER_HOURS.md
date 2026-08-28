# Calendarios de feriados e politicas extra expediente

## Objetivo e contexto

Este modulo privado permite tratar feriados como periodo fora do expediente e
dar ao cliente uma saida segura da fila enquanto nao ha atendimento humano.

O desenho separa duas responsabilidades:

- calendarios de feriados, vinculados diretamente aos departamentos;
- politicas extra expediente, vinculadas as politicas nomeadas de distribuicao.

O departamento nao seleciona diretamente uma politica extra expediente. Ele
continua vinculado a uma politica nomeada de distribuicao, e essa politica
define a acao `after_hours_policy` em `outside_business_hours`.

## Comportamento operacional

A avaliacao segue esta ordem:

1. Resolve a politica de distribuicao efetiva para canal e departamento.
2. Resolve o calendario vinculado ao departamento atual.
3. Verifica se a data local da politica e um feriado cadastrado.
4. Se for feriado, considera a conversa fora do horario antes de avaliar a
   grade normal de funcionamento.
5. Se nao for feriado, aplica o modo de horario configurado na politica:
   herdar do canal, sempre disponivel ou agenda personalizada.
6. Executa a acao configurada em `outside_business_hours`.

A grade semanal e os intervalos sao avaliados pelo service privado
`Ibsoft::ConversationDistribution::BusinessHoursEvaluator`. A decisao final e
a precedencia do feriado continuam concentradas no `DecisionResolver`.

A acao `after_hours_policy` e permitida somente para fora do horario. A regra
de ausencia de agente continua independente e nao pode selecionar uma politica
extra expediente.

Quando a politica extra expediente esta habilitada:

- a conversa precisa estar aberta, sem agente e vinculada ao mesmo
  departamento avaliado;
- o sistema envia a mensagem normal ou a mensagem de feriado;
- cria uma espera ativa e registra o comando comunicado ao cliente;
- uma mensagem recebida, publica e exatamente igual ao comando encerra a
  conversa por completo e envia a confirmacao configurada;
- mensagens privadas, mensagens de saida e textos que apenas contem o comando
  nao encerram o atendimento;
- atribuicao a um agente, mudanca de departamento ou encerramento externo
  cancelam a espera ativa.

O comando e a confirmacao sao copiados para a espera no momento em que ela e
iniciada. Alterar a politica depois disso nao muda o contrato que ja foi
informado ao cliente.

Ao excluir uma politica extra expediente, as politicas de distribuicao
vinculadas voltam atomicamente para a acao `wait`. A exclusao e bloqueada se
existir uma espera ativa, evitando mudanca parcial ou perda do fluxo em curso.

## Escopo dos feriados

O modulo suporta:

- feriados nacionais;
- feriados estaduais;
- pontos facultativos, quando explicitamente incluidos na importacao;
- datas cadastradas manualmente.

Feriados municipais nao fazem parte deste contrato. A importacao automatica e
uma acao administrativa explicita; nao existe sincronizacao periodica nem job
de importacao.

Datas manuais prevalecem durante uma importacao. Se a API retornar a mesma
data, o registro manual e preservado e informado como ignorado.

## Fluxo administrativo do calendario

O editor de calendario separa responsabilidades em tres abas:

- `Geral`: nome e identidade do calendario;
- `Feriados`: cadastro manual, manutencao e acesso a sincronizacao;
- `Departamentos`: busca e vinculos dos departamentos que seguem o calendario.

A sincronizacao automatica nao ocupa o formulario principal. O administrador
aciona `Sincronizar feriados` na aba de feriados e usa um segundo modal para:

1. escolher ano, estado e inclusao opcional de pontos facultativos;
2. consultar a Invertexto sem persistir dados;
3. selecionar uma data, varias datas ou todos os resultados;
4. importar somente a selecao confirmada.

Nenhuma data vem selecionada automaticamente. As datas sao exibidas ao usuario
em `dd/mm/aaaa`, mas continuam trafegando pela API no formato ISO `aaaa-mm-dd`.
O calendario precisa existir antes da sincronizacao, evitando criar registros
parciais durante a edicao inicial.

O endpoint de importacao aceita `holiday_dates` como uma lista opcional de
datas ISO. Quando ela e informada, o backend consulta novamente a Invertexto e
importa somente a intersecao entre as datas escolhidas e a resposta
normalizada. Assim, nome, tipo e abrangencia do feriado nunca sao aceitos do
navegador. A omissao de `holiday_dates` preserva o contrato anterior de
importacao integral para consumidores internos existentes.

## Variaveis de ambiente

### IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN

Token privado usado somente pelo backend Rails para consultar a API Invertexto.
Ele nao e persistido no banco e nunca e enviado ao navegador.

```env
IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN=configure-via-secret-manager
```

A variavel e obrigatoria apenas para visualizar ou importar feriados da API.
Sem ela, cadastro manual, vinculos e deteccao de feriados ja salvos continuam
funcionando normalmente.

## Estrutura backend

Models:

- `app/models/ibsoft/business_calendar/calendar.rb`
- `app/models/ibsoft/business_calendar/holiday.rb`
- `app/models/ibsoft/business_calendar/team_link.rb`
- `app/models/ibsoft/after_hours/policy.rb`
- `app/models/ibsoft/after_hours/wait.rb`

Services de calendario:

- `app/services/ibsoft/business_calendar/cache.rb`
- `app/services/ibsoft/business_calendar/calendar_resolver.rb`
- `app/services/ibsoft/business_calendar/holiday_resolver.rb`
- `app/services/ibsoft/business_calendar/invertexto_client.rb`
- `app/services/ibsoft/business_calendar/holiday_importer.rb`
- `app/services/ibsoft/business_calendar/team_link_updater.rb`
- `app/services/ibsoft/business_calendar/calendar_team_links_updater.rb`

Services extra expediente:

- `app/services/ibsoft/after_hours/wait_starter.rb`
- `app/services/ibsoft/after_hours/exit_command_handler.rb`
- `app/services/ibsoft/after_hours/wait_reconciler.rb`
- `app/services/ibsoft/after_hours/policy_destroyer.rb`
- `app/services/ibsoft/after_hours/agent_bot_listener_extension.rb`

Integracao com a distribuicao:

- `app/services/ibsoft/conversation_distribution/business_hours_evaluator.rb`
- `app/services/ibsoft/conversation_distribution/decision_resolver.rb`
- `app/services/ibsoft/conversation_distribution/decision_action_executor.rb`
- `app/services/ibsoft/conversation_distribution/effective_policy_resolver.rb`
- `app/services/ibsoft/conversation_distribution/unavailability_config_validator.rb`

Controllers:

- `app/controllers/api/v1/accounts/ibsoft/business_calendar/`
- `app/controllers/api/v1/accounts/ibsoft/after_hours/`

## Estrutura frontend

- `app/javascript/dashboard/ibsoft/businessCalendar/`
- `app/javascript/dashboard/ibsoft/afterHours/`
- `app/javascript/dashboard/ibsoft/components/IbsoftDialogHeader.vue`: cabecalho
  compartilhado pelos modais privados, com titulo, descricao opcional e acao
  de fechamento sem alterar o `Dialog` nativo do Chatwoot.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`
- `app/javascript/dashboard/ibsoft/chathubSettings/components/DistributionPolicyCatalog.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/DistributionPolicyForm.vue`
- `app/javascript/dashboard/ibsoft/conversationDistribution/components/TeamDistributionSettingsModal.vue`

Textos ficam em arquivos proprios:

- `app/javascript/dashboard/i18n/locale/*/ibsoftBusinessCalendar.json`
- `app/javascript/dashboard/i18n/locale/*/ibsoftAfterHours.json`

## Banco e migracoes

Migracoes:

- `db/migrate/20260816100000_create_ibsoft_business_calendars_and_after_hours_policies.rb`
- `db/migrate/20260816110000_snapshot_ibsoft_after_hours_wait_messages.rb`

Tabelas:

- `ibsoft_business_calendars`
- `ibsoft_business_holidays`
- `ibsoft_business_calendar_team_links`
- `ibsoft_after_hours_policies`
- `ibsoft_after_hours_waits`

A tabela de politicas nomeadas recebe apenas a referencia opcional
`after_hours_policy_id`. A espera armazena causa, departamento, calendario,
feriado, mensagens relacionadas, comando e confirmacao efetivamente usados.

## API privada

Todas as rotas sao isoladas por conta em
`/api/v1/accounts/:account_id/ibsoft`.

Calendarios:

- `GET|POST /business_calendar/calendars`
- `GET|PATCH|DELETE /business_calendar/calendars/:id`
- `PUT /business_calendar/calendars/:calendar_id/team_links`
- `GET|POST /business_calendar/calendars/:calendar_id/holidays`
- `PATCH|DELETE /business_calendar/calendars/:calendar_id/holidays/:id`
- `POST /business_calendar/calendars/:calendar_id/holiday_import/preview`
- `POST /business_calendar/calendars/:calendar_id/holiday_import`
- `GET|PUT|DELETE /business_calendar/team_links/:team_id`

Politicas extra expediente:

- `GET|POST /after_hours/policies`
- `GET|PATCH|DELETE /after_hours/policies/:id`

## Permissoes e isolamento por conta

Os controllers usam a permissao privada de configuracoes ChatHub. Um
administrador possui acesso; outro usuario precisa receber explicitamente a
permissao `ibsoft_chathub_settings_manage`.

Calendarios, departamentos, politicas, esperas e politicas de distribuicao sao
sempre consultados dentro da conta da requisicao. IDs de outra conta nao sao
aceitos nem expostos.

## Cache, concorrencia e escala

O calendario vinculado ao departamento e o feriado da data usam
`Rails.cache`, com chaves contendo conta, departamento, calendario e data. As
alteracoes invalidam as chaves afetadas, inclusive a data anterior quando um
feriado e movido.

O cache compartilhado torna o modulo compativel com multiplas instancias Rails.
Nao ha memoria de processo como fonte de verdade.

Alteracoes de vinculos entre calendarios e departamentos usam transacoes e
locks ordenados no banco. Assim, edicoes simultaneas pelo calendario e pelo
modal do departamento nao criam vinculos duplicados nem perdem atualizacoes.

Inicio, conclusao e reconciliacao de esperas usam locks de banco e uma unica
espera por conversa. Isso evita mensagens duplicadas e impede que um evento
atrasado sobrescreva uma espera ja concluida. O modulo nao depende de polling,
cron ou worker dedicado; ele reage a avaliacao da distribuicao e aos eventos ja
emitidos pela aplicacao.

## Pontos de acoplamento

Pontos pequenos e intencionais:

- `config/routes.rb`: registra as APIs privadas.
- `app/javascript/dashboard/i18n/locale/*/index.js`: registra traducoes.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`: registra
  as duas secoes privadas no menu existente.
- model/controller/resolver/executor da distribuicao Ibsoft: transportam a
  referencia da politica e tratam feriado como fora do horario.
- `TeamDistributionSettingsModal.vue` e API de politica do departamento:
  exibem o vinculo do calendario sem mover a regra para componente nativo.
- `config/initializers/ibsoft_after_hours.rb`: aplica um `prepend` privado no
  listener de eventos. O arquivo nativo `AgentBotListener` permanece intacto.

Nao ha alteracao em models, webhook processors ou jobs centrais do Chatwoot.

## Riscos e cuidados

- Uma politica extra expediente desabilitada degrada para `wait`.
- O comando e comparado de forma exata depois de normalizar espacos e caixa.
- A deteccao usa a data local da politica de distribuicao efetiva.
- Um departamento sem calendario continua seguindo somente o expediente.
- O token Invertexto deve ficar em secret manager e nunca em Git, log ou banco.
- A API externa nao participa do caminho de atendimento em tempo real. Falha
  nela afeta apenas a importacao solicitada pelo administrador.

## Atualizacao do upstream

Ao sincronizar com o Chatwoot:

1. Preservar os namespaces privados `business_calendar` e `after_hours` em
   `config/routes.rb`.
2. Verificar os registros dos locales Ibsoft.
3. Conferir o carregamento do initializer e o contrato publico de
   `AgentBotListener` usado pelo `prepend`.
4. Revisar os pontos Ibsoft da distribuicao: policy, effective resolver,
   decision resolver, action executor, validator e payloads.
5. Executar migrations e toda a bateria abaixo.
6. Validar manualmente calendario, feriado, expediente normal, comando de saida
   e cancelamento por atribuicao.

## Testes e lint

### Matriz de cobertura

| Area | Cenarios protegidos | Specs principais |
| --- | --- | --- |
| Calendario | nome obrigatorio e unico por conta, payload ordenado e exclusao em cascata somente dos registros privados | `calendar_spec.rb` |
| Feriado | tipos/fontes/abrangencias, UF, data e nome, duplicidade por calendario, mesma data em outra conta e invalidacao de cache | `holiday_spec.rb` |
| Vinculos | um calendario por departamento, conta consistente, criar, substituir, remover, selecao vazia, IDs invalidos e transacao sem atualizacao parcial | `team_link_spec.rb`, `team_link_updater_spec.rb`, `calendar_team_links_updater_spec.rb` |
| Resolucao | calendario ausente, data encontrada, conta isolada e invalidacao ao criar, mover ou excluir uma data | `holiday_resolver_spec.rb` |
| Invertexto | token somente no servidor, Bearer, consulta nacional/estadual, resposta de erro controlada e ausencia de chamadas reais nos testes | `invertexto_client_spec.rb` |
| Importacao | nacional, estadual, ponto facultativo opcional, selecao parcial, data desconhecida, UF invalida, preservacao manual e ausencia de feriados municipais | `holiday_importer_spec.rb` e requests de `holiday_import` |
| Politica extra expediente | mensagens obrigatorias somente quando ativa, nome por conta, comando normalizado, multiline/limite e bloqueio de exclusao com espera ativa | `policy_spec.rb`, `policy_destroyer_spec.rb` |
| Espera | snapshot do comando/mensagem, associacoes por conta, estados, unicidade, mensagem normal/feriado, idempotencia e falhas de entrega | `wait_spec.rb`, `wait_starter_spec.rb` |
| Comando de saida | igualdade exata sem diferenciar caixa, texto parcial, mensagem anterior, privada/de saida, mudanca de agente/departamento/status, entrega da confirmacao e execucao unica | `exit_command_handler_spec.rb` |
| Reconciliacao | espera preservada, atribuicao, transferencia, encerramento e espera ja concluida | `wait_reconciler_spec.rb` |
| Interface | abas, modais, selecao e importacao, datas `dd/mm/aaaa`, busca de departamento, CRUD, estados vazios e erros de API/salvamento | `BusinessCalendarCatalog.spec.js`, `AfterHoursPolicyCatalog.spec.js`, `IbsoftDialogHeader.spec.js` |

As chamadas da Invertexto sao simuladas nos testes. A suite nunca importa nem
modifica dados externos reais.

Backend:

```bash
RAILS_ENV=test RACK_ENV=test bundle exec rspec \
  spec/models/ibsoft/business_calendar \
  spec/models/ibsoft/after_hours \
  spec/services/ibsoft/after_hours \
  spec/requests/api/v1/accounts/ibsoft/after_hours \
  spec/services/ibsoft/business_calendar \
  spec/requests/api/v1/accounts/ibsoft/business_calendar \
  spec/services/ibsoft/conversation_distribution/decision_resolver_spec.rb \
  spec/services/ibsoft/conversation_distribution/decision_action_executor_spec.rb
```

Frontend:

```bash
pnpm exec vitest run \
  app/javascript/dashboard/ibsoft/afterHours/specs \
  app/javascript/dashboard/ibsoft/businessCalendar/specs \
  app/javascript/dashboard/ibsoft/conversationDistribution/specs/TeamDistributionSettingsModal.spec.js
```

Lint:

```bash
bundle exec rubocop app/models/ibsoft/after_hours app/models/ibsoft/business_calendar \
  app/services/ibsoft/after_hours app/services/ibsoft/business_calendar \
  app/controllers/api/v1/accounts/ibsoft/after_hours \
  app/controllers/api/v1/accounts/ibsoft/business_calendar
pnpm exec eslint app/javascript/dashboard/ibsoft/afterHours \
  app/javascript/dashboard/ibsoft/businessCalendar
```

## Checklist de producao

1. Rodar `bundle exec rails db:migrate`.
2. Definir o token Invertexto apenas se a importacao sera usada.
3. Recriar o container Rails depois de alterar variaveis de ambiente.
4. Criar um calendario e vincula-lo a um departamento de teste.
5. Cadastrar ou importar uma data de teste.
6. Vincular uma politica extra expediente a politica de distribuicao.
7. Validar mensagem normal, mensagem de feriado e comando de saida.
8. Validar que atribuicao, transferencia e encerramento externo cancelam a
   espera.
