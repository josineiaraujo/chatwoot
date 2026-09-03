# Auditoria de integracao do Chatwoot v4.17.1

Este documento define o gate de regressao para integrar o Chatwoot `v4.17.1`
na camada privada Ibsoft. Ele nao autoriza publicacao por si so. A promocao
para producao depende de todos os gates deste documento passarem no commit
integrado final.

## Escopo auditado

- Base privada auditada: `9fa78c1c702b`.
- Tag oficial anotada: `v4.17.1`, objeto `e194a693e2db`, apontando para o
  commit `b354a9550e1f`.
- Base oficial atual da camada privada: `v4.16.2`.
- Commits oficiais no intervalo: 201.
- Arquivos alterados pelo upstream: 2.049.
- Commits existentes sobre `v4.16.2` na camada privada: 101.
- Arquivos modificados pelos dois lados: 81.
- Conflitos de conteudo previstos por `git merge-tree`: 15.

O trabalho de preparacao foi feito na branch
`private/upstream-v4-17-1-regression`, em worktree isolado. Nenhum merge do
upstream foi aplicado a `ibsoft/develop` ou `ibsoft/production` nesta etapa.

## Conflitos obrigatorios

Cada arquivo abaixo exige resolucao manual e teste direcionado. Nao aceitar
automaticamente um dos lados:

1. `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`
2. `app/javascript/dashboard/components-next/filter/provider.js`
3. `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
4. `app/javascript/dashboard/components/widgets/conversation/contextMenu/Index.vue`
5. `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`
6. `app/javascript/dashboard/routes/dashboard/settings/inbox/components/specs/AccountHealth.spec.js`
7. `app/javascript/dashboard/routes/dashboard/settings/reports/components/heatmaps/BaseHeatmap.vue`
8. `app/services/action_service.rb`
9. `app/services/auto_assignment/agent_assignment_service.rb`
10. `app/services/whatsapp/template_processor_service.rb`
11. `db/schema.rb`
12. `spec/controllers/api/v1/accounts/search_controller_spec.rb`
13. `spec/finders/conversation_finder_spec.rb`
14. `spec/models/concerns/auto_assignment_handler_shared.rb`
15. `spec/services/auto_assignment/agent_assignment_service_spec.rb`

Arquivos que o Git consegue mesclar automaticamente ainda exigem revisao
semantica quando estiverem entre os 81 arquivos compartilhados. Merge limpo
nao significa comportamento preservado.

## Mudancas oficiais com impacto privado

### Propriedade de conversas por IA

O upstream adiciona `conversations.ai_assignee_type` e a associacao
polimorfica `ai_assignee`, reutilizando `assignee_agent_bot_id`. Limpar apenas
`assignee_agent_bot` pode deixar o tipo polimorfico obsoleto.

Na integracao, todos os fluxos privados que retiram a conversa do robo devem
usar o contrato oficial completo, preferencialmente `ai_assignee: nil`:

- transferencia manual para departamento;
- retorno para fila;
- atribuicao manual;
- handoff de automacao;
- encerramento de automacao;
- acoes de politica que removem proprietario.

A preparacao introduz
`app/services/ibsoft/conversation_ownership/clearer.rb` como contrato privado
unico. Na base atual ele limpa o agente e o `AgentBot`; quando a API tipada
existir, tambem atribui `ai_assignee = nil`, eliminando o tipo polimorfico. Os
chamadores permanecem dentro de seus locks e transacoes existentes.

### Concorrencia nas atribuicoes

O controller oficial passa a atualizar departamentos dentro de `with_lock`.
O preparador privado deve executar dentro do mesmo lock; executar antes dele
mantem uma janela de corrida entre limpeza do robo, marcacao da origem e
persistencia do departamento.

O mesmo cuidado vale para `ActionService`, atribuicao automatica e callbacks
de `Conversation`.

### Editor e acoes da conversa

O `ReplyBox.vue` oficial passa a combinar novos fluxos de takeover de AgentBot,
macros, rascunhos, Instagram e templates. A protecao privada que impede envio
sem atribuicao deve ser reaplicada sobre a implementacao oficial final, sem
remover nenhum desses fluxos.

O menu de contexto e as acoes de resolver tambem devem preservar transferencia
privada, retorno para fila e atualizacao coerente das contagens.

### Filtros e busca

O provider oficial passa a expor filtros agrupados com icones. A integracao
deve manter:

- `filterTypes` e o novo `attributeFilterTypes` oficiais;
- filtro privado `ibsoft_protocol`;
- rotulo operacional privado para o status `pending`;
- filtros frontend alinhados ao backend para conversas humanas e de robo;
- datas `YYYY-MM-DD` interpretadas no calendario local.

O v4.17.1 ja trata datas simples no calendario local antes de delegar ao pacote
`@chatwoot/utils`. A duplicacao do backport privado foi removida; a unica
diferenca restante em `filterHelpers.js` e o protocolo privado de conversa.

### WhatsApp e templates

O upstream amplia o gerenciamento e o processamento nativos de templates.
Preservar:

- headers de texto nomeados e posicionais;
- headers de imagem e documento;
- botoes URL, copiar codigo e detalhes de ordem;
- payload `interactive.action` como objeto, conforme aceito pela Meta;
- BSUID em `recipient`, mantendo numeros em `to`;
- abertura e atualizacao de ordens, inclusive fallback por template fora da
  janela de 24 horas.

### Perfil, inbox e permissoes

O partial de perfil oficial passa a carregar `account_users` e `custom_role`
de forma otimizada. O resultado final deve somar as permissoes nativas com
`Ibsoft::PermissionRegistry` por conta, sem vazar permissoes entre contas.

O payload de inbox deve preservar `ibsoft_working_hour_breaks`, inclusive nas
respostas usadas pelas configuracoes e pelo widget.

### Datas, relatorios e saude do WhatsApp

O upstream substitui a heatmap por `@chatwoot/viz`. O componente final deve
continuar usando o locale ativo do dashboard nas descricoes de data.

O `v4.17.1` ja contem a normalizacao de locale usada pelo `AccountHealth`.
Durante o merge, remover duplicacao do backport privado somente depois de o
teste com `pt_BR` permanecer verde.

### Licenca e plano da instalacao

O intervalo oficial nao altera `ChatwootHub`, `ChatwootApp`, a gravacao de
`INSTALLATION_PRICING_PLAN`, o limite de agentes nem o reconciliador de
features da instalacao. As mudancas de plano encontradas pertencem a recursos
cloud e Captain. Portanto, o v4.17.1 nao muda o criterio pelo qual esta
instalacao self-hosted entende uma licenca como valida.

O comportamento privado que fixa `enterprise` e a quantidade `9.999.999`
continua vindo do trigger PostgreSQL presente na base anterior. Ele foi
preservado no schema e no caminho real de upgrade e possui teste de regressao;
nao e uma nova regra do upstream.

### Dependencias frontend

O upstream substitui `@scmmishra/pico-search` por
`@chatwoot/pico-search`. Todo import privado deve ser migrado; atualmente o
ponto conhecido e
`app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`.
Uma busca global e um build de producao sao obrigatorios antes da promocao.

Os pacotes removidos `chart.js`, `vue-chartjs` e `md5`, assim como o cliente
Azure substituido, nao possuem consumidores na camada privada. Os imports
privados restantes de `@chatwoot/utils` e `@chatwoot/pico-search` tiveram seus
exports verificados na instalacao final e foram exercitados pelo build.

### Rails 7.2

O upgrade oficial para Rails `7.2.3.1` passou pela suite completa e pelo
eager-load. Models privados do chat interno ainda usam a forma keyword de
`enum`, aceita no Rails 7.2 mas anunciada como obsoleta para Rails 8. Essa
mensagem nao afeta a integracao atual; deve virar uma tarefa isolada antes de
um futuro upgrade para Rails 8, sem misturar a alteracao neste merge.

## Matriz de cobertura

| Contrato | Cobertura antes do merge | Gate depois do merge |
| --- | --- | --- |
| Transferencia manual e propriedade do robo | request spec, `ConversationOwnership::Clearer` e fluxos de fila/automacao verificam proprietario completo | exigir `assignee_agent_bot_id` e `ai_assignee_type` nulos e operacao dentro de `with_lock` |
| Fila, automacoes e visibilidade por inbox | services, finders, policies e specs frontend privados | repetir suites com conversas User, AgentBot e novo `ai_assignee` |
| Atribuicao automatica e concorrencia | specs de atribuicao, claim e casos stale | repetir specs oficiais e privados apos resolver os conflitos |
| ReplyBox sem atribuicao | specs privados de guard, banner, arquivo, template e midia | repetir sobre o ReplyBox oficial com takeover, macro e draft |
| Filtro de protocolo e status | provider privado, protocolo e helper com 96 casos | preservar agrupamento oficial e extensoes privadas |
| Rotas privadas | teste de registro dos seis conjuntos de rotas | executar teste e smoke de navegacao com cada permissao |
| Permissoes privadas | request de perfil verifica isolamento por conta | validar administrador, agente, perfil customizado e sem permissao |
| Pausas e expediente | model, evaluator, policies e payload de inbox | validar canal, departamento, feriado e politica extra expediente |
| WhatsApp interativo | specs Cloud e 360dialog validam objeto `action` | repetir com implementacao oficial e chamada stubada |
| Templates e ordens | suites Meta Templates, External Messaging e Broadcast | repetir templates standard/order e atualizacoes dentro/fora de 24h |
| Criptografia | round-trip e texto bruto para ERP, endpoint e delivery | executar com as tres chaves de criptografia presentes |
| Locale | AccountHealth, heatmap e hook do App | validar `pt_BR`, `pt-BR`, claro/escuro e build final |
| Realtime e contagens | Action Cable, status e alertas privados | validar eventos em massa, fila, automacoes e supervisao aberta |
| Enterprise | policy e services compartilhados inventariados | executar specs enterprise dos arquivos tocados |

## Linha de base validada

Executada em 2 de setembro de 2026, antes do merge:

- Node `24.x`, dependencias instaladas com
  `pnpm install --force --frozen-lockfile --shamefully-hoist` no worktree
  isolado. O hoisting e necessario porque o `postcss.config.js` atual carrega
  `postcss-import`, que chega de forma transitiva pelo Tailwind.
- Frontend privado e pontos nativos: 79 arquivos, 454 testes, 0 falhas.
- Backend privado e pontos nativos: 1.405 exemplos, 0 falhas.
- Testes Ruby executados com Ruby 3.4.4, PostgreSQL 16 e Redis efemeros.
- Chaves de Active Record Encryption foram fornecidas ao ambiente de teste;
  os testes de criptografia nao foram ignorados.
- ESLint dos arquivos alterados: sem erros.
- RuboCop dos arquivos alterados: sem offenses.

Avisos de dependencias e deprecacoes nao foram tratados como falha funcional,
mas devem ser reavaliados com Rails 7.2 no candidato integrado.

## Resultado do candidato integrado

Executado em 2 de setembro de 2026 na branch isolada
`private/upstream-v4-17-1-regression`. O merge ainda nao foi promovido nem
publicado.

### Compatibilidades corrigidas

- O catalogo privado de disparos passou a delegar a sincronizacao ao contrato
  publico `sync_templates` do provider oficial. Isso preserva a paginacao e o
  token de gerenciamento da v4.17.1, evita uma segunda validacao remota e nao
  apaga o cache quando a Meta falha.
- A atribuicao de equipe usa
  `Ibsoft::ConversationDistribution::ActionServiceExtension`, conectada por
  initializer privado. Um contexto limitado a chamada permite que o concern
  privado da conversa inclua o marcador no mesmo `update!` oficial. Ela nao
  grava o marcador nem atualiza a conversa quando outro processo ja aplicou a
  mesma equipe, preserva `TEAM_CHANGED` e mantem a marcacao na mesma transacao;
  `app/services/action_service.rb` ficou identico ao upstream.
- Os specs de atividade de conversa passaram a validar a traducao carregada,
  preservando a terminologia privada `closed` sem alterar o core de producao.
- O unico import privado de `@scmmishra/pico-search` foi migrado para
  `@chatwoot/pico-search`.
- O perfil do usuario passou a combinar permissoes pelo concern privado
  `AccountUserPermissions`. Um cache limitado ao contexto da requisicao carrega
  as atribuicoes uma vez por usuario, sem vazar permissoes entre contas;
  `app/views/api/v1/models/_user.json.jbuilder` ficou identico ao upstream.
- Os defaults privados de localizacao agora sao conectados por callbacks do
  autoloader. Isso evita carregar `Account` e, por consequencia, `Team` antes
  da inicializacao das traducoes, sem perder os hooks apos reload de codigo. O
  fuso de relatorios e aplicado apenas na criacao e pode ser removido depois,
  como previsto pelo contrato oficial.
- A comparacao final com a base privada anterior nao encontrou novo arquivo de
  runtime nativo divergente do upstream. As novas conexoes de backend ficaram
  em namespaces, concerns, services e initializers `Ibsoft`.
- Na comparacao dos arquivos rastreados, 35 divergencias historicas deixaram de
  existir e somente 19 arquivos passaram a divergir. O unico arquivo de
  runtime desse segundo grupo e o service privado
  `Ibsoft::ConversationOwnership::Clearer`; os demais sao documentacao e
  testes. Todos os arquivos novos ainda nao rastreados tambem estao em
  namespaces privados ou em diretorios de teste.

### Banco e migrations

- `db:prepare`, `db:migrate:status` e `db:abort_if_pending_migrations` passaram
  em PostgreSQL 16 isolado, com as tres chaves de Active Record Encryption.
- A verificacao final nao encontrou indices invalidos em `pg_index`; o banco
  de testes terminou com zero contas, conversas, respostas prontas e
  configuracoes de instalacao, confirmando ausencia de contaminacao por seeds.
- Uma copia criada a partir do `db/schema.rb` da base privada v4.16.2 recebeu
  com sucesso as 19 migrations oficiais novas.
- Foram confirmados `ai_assignee_type`, tabelas de automacoes pendentes,
  recipients de campanhas, foreign keys e estruturas privadas de disparos,
  cobranca, feriados e politicas extra expediente.
- A reproducao de todo o historico desde um banco totalmente vazio para na
  migration antiga `20231211010807_add_cached_labels_list.rb`, que referencia
  `ActsAsTaggableOn::Taggable::Cache`. A migration e identica na base anterior
  e no upstream; o caminho real de upgrade v4.16.2 -> v4.17.1 passou.
- O schema privado contem o trigger `trg_force_enterprise_configs`, mas nao foi
  localizada uma migration correspondente no historico atual. O trigger foi
  preservado no upgrade e em bancos carregados pelo schema; incorporar a camada
  privada sobre um banco oficial que nunca a recebeu exige um gate especifico.
  Este risco ja existia na v4.16.2 e nao foi introduzido pelo v4.17.1.
- A migration `AddAiAssigneeTypeToConversations` adiciona uma coluna opcional,
  percorre `conversations` em faixas de 100.000 registros e atualiza as
  conversas atribuidas a bot em lotes de 1.000. Ela e retomavel porque ignora
  linhas ja preenchidas, mas o tempo, WAL e uso de I/O devem ser medidos em uma
  copia representativa da producao.
- A migration `EnqueueCopyCaptainAutoResolveModeToAssistantsJob` agenda um job
  na fila `async_database_migration` quando a instalacao e Enterprise. O
  Sidekiq antigo deve estar parado durante a migration para nao tentar executar
  uma classe que existe apenas na imagem nova. A fila ja esta registrada em
  `config/sidekiq.yml`.
- Os indices maiores sobre `conversations`, `audits` e `agent_sessions` usam
  `algorithm: :concurrently`. Isso reduz bloqueio de escrita, mas continua
  consumindo I/O e pode deixar indice invalido se o processo for interrompido;
  o gate de banco deve verificar `pg_index.indisvalid` depois da migration.
- A alteracao retroativa em
  `20230515051424_update_article_image_keys.rb` troca o acesso legado a
  `Rails.application.secrets.secret_key_base` pela API do Rails 7.2. Ela afeta
  apenas instalacoes que ainda nao registraram essa migration; em um upgrade
  normal ela nao e executada novamente.

### Testes automatizados

- Backend privado: 204 arquivos, 1.231 exemplos, 0 falhas.
- Nucleo compartilhado: 600 exemplos, 0 falhas.
- Enterprise compartilhado: 117 exemplos, 0 falhas.
- Automacoes e autoatribuicao ampliadas: 292 exemplos, 0 falhas.
- WhatsApp alterado pela v4.17.1: 168 exemplos, 0 falhas.
- Backend completo, em banco carregado pelo schema sem seeds e com as tres
  chaves de Active Record Encryption: 10.052 exemplos, 0 falhas, em 11 minutos
  e 4 segundos. Esta foi a execucao integral definitiva, feita depois dos
  testes adicionais de localizacao, sincronizacao de templates, controle de
  acesso e integracao privada com `ActionService`.
- Frontend privado: 76 arquivos, 352 testes, 0 falhas.
- Frontend dos pontos nativos compartilhados: 8 arquivos, 288 testes, 0
  falhas.
- Frontend completo: 501 arquivos, 4.642 testes, 0 falhas.
- RuboCop: 37 arquivos Ruby resolvidos, adaptados ou adicionados, sem offenses.
- ESLint: sem erros; permanece um warning preexistente de chave i18n dinamica
  em `ResolveAction.vue`.
- O eager-load integral em `RAILS_ENV=production` confirmou os quatro hooks
  privados de localizacao, a mensagem traduzida do validador de `Team` e os
  tres novos adapters privados de controle de acesso e distribuicao, sem
  carregamento prematuro de traducoes.

Os lotes de backend acima possuem arquivos em comum e nao devem ser somados
como se fossem exemplos unicos.

Uma primeira repeticao integral do backend foi invalidada porque `db:prepare`
executou seeds ao criar o banco de teste. A suite iniciou com contas,
conversas e configuracoes globais persistidas, produzindo 421 falsos
positivos. Depois de recriar o banco com `db:schema:load`, sem seeds, foram
identificados dois vazamentos de contexto dependentes da ordem dos specs. O
suporte privado agora limpa `Current` e o cache privado antes de cada exemplo,
sem alterar specs ou runtime nativos. A repeticao definitiva passou e terminou
com zero contas, conversas, respostas prontas, configuracoes de instalacao e
chaves no Redis.

### Build

- O `assets:precompile` final de producao concluiu SDK, Sprockets e dashboard
  Vite sobre a arvore definitiva, com Node 24, Ruby 3.4.4 e 5.657 modulos
  frontend transformados.
- `extractFilenameFromUrl` foi confirmado entre os exports instalados de
  `@chatwoot/utils`.
- O smoke final respondeu HTTP 200 em `http://localhost:3100/`, e
  `bundle check`, `git diff --check` e a verificacao de conflitos pendentes
  passaram.
- Nao houve erro de import ou export. Permanecem warnings nao bloqueantes de
  Browserslist, sintaxe legada `::v-deep`, tamanho de chunks e imports
  simultaneamente estaticos e dinamicos. O `husky install` tambem informou que
  o caminho Git do worktree nao existe dentro do container isolado; o comando
  e o build terminaram com codigo zero e isso nao ocorre por falha da
  aplicacao.

### Pendencias antes de producao

- Executar a homologacao operacional completa do Gate 4 em navegador.
- Validar Meta, IXC e SGP reais em uma conta controlada.
- Aplicar as migrations em copia sanitizada e representativa da producao.
- Gerar e testar a imagem final identificada pelo commit integrado.
- Concluir backup, rollback, canary e monitoramento do Gate 5.

## Gates obrigatorios depois do merge

### Gate 1: arvore e dependencias

- Nenhum conflito, marcador ou arquivo nao rastreado relacionado ao merge.
- `git diff --check` sem erros.
- `pnpm install --force --frozen-lockfile --shamefully-hoist` com Node 24,
  enquanto `postcss-import` nao for dependencia direta do projeto.
- Nenhum import restante de `@scmmishra/pico-search`.
- `bundle check` com Ruby 3.4.4.
- Revisao manual dos 81 arquivos compartilhados, nao apenas dos 15 conflitos.

### Gate 2: banco

- Validar separadamente uma primeira instalacao com `db:prepare`, incluindo os
  seeds esperados pelo produto.
- Para a suite automatizada, purgar o banco de teste e carregar apenas o schema
  com `RAILS_ENV=test bundle exec rails db:schema:load`; nao executar seeds.
- Aplicar migrations em copia sanitizada do banco de producao.
- Antes do ensaio, medir o total de conversas, as conversas atribuidas a bot e
  o tamanho de `conversations`, `audits` e `agent_sessions`; registrar duracao,
  crescimento de WAL e pico de I/O do backfill.
- Conferir `db:migrate:status` e `db:abort_if_pending_migrations`.
- Verificar colunas privadas recentes, `ai_assignee_type`, indices e foreign
  keys.
- Confirmar que nao restou indice invalido em `pg_index` e que o job
  `Migration::CopyCaptainAutoResolveModeToAssistantsJob` foi processado pela
  imagem nova.
- Fazer round-trip de todos os campos criptografados com as chaves reais do
  ambiente de homologacao.

### Gate 3: testes automatizados

- Repetir integralmente as suites registradas na linha de base.
- Executar todos os specs oficiais adicionados no intervalo para WhatsApp,
  atribuicao, filtros, busca, relatorios e conversas.
- Executar specs enterprise relacionados aos arquivos compartilhados.
- Executar ESLint e RuboCop nos arquivos resolvidos.
- Gerar o build frontend e a imagem de producao sem warnings de import ou
  export ausente.

### Gate 4: homologacao operacional

- Administrador, agente comum e agente com perfil privado.
- Inbox autorizada e nao autorizada.
- Conversa humana, conversa com AgentBot e conversa com novo proprietario de
  IA.
- Transferir, atribuir, devolver para fila, resolver em massa e reabrir.
- Confirmar contagens de fila e automacoes via eventos e reconciliacao.
- Disparo unico e multiplo nos tres modos de registro de conversa.
- IXC e SGP: busca, filtros, grupos, telefone prioritario e fallback.
- API de cobranca: standard, order, reenvio e atualizacao de ordem.
- Template com header, documento, variaveis e botoes.
- Feriado, pausa, dentro e fora do expediente, comando de saida e watchdog.
- Chat interno, anexos, realtime e notificacao sonora da supervisao.
- Tema claro/escuro, mobile e locale `pt_BR`.

### Gate 5: publicacao

- Backup testado e rollback documentado.
- Imagem identificada por commit imutavel, nunca apenas por tag mutavel.
- Parar o Sidekiq antigo, executar migrations com a imagem nova e somente
  entao iniciar os novos processos Rails e Sidekiq. Essa ordem impede que o job
  de migration do Captain seja consumido por codigo antigo.
- Canary em uma conta controlada antes da liberacao geral.
- Monitorar erros 5xx, jobs mortos, latencia, Redis, conexoes PostgreSQL e
  rejeicoes Meta durante a janela de publicacao.

## Validacoes que nao podem ser substituidas por teste unitario

- Respostas reais da Meta e mudancas externas de contrato.
- Respostas reais dos ambientes IXC e SGP.
- Compatibilidade de dados com uma copia representativa da producao.
- Comportamento visual e acessibilidade no navegador.
- Corridas dependentes de carga real entre Rails, Sidekiq, Redis e PostgreSQL.

Por esse motivo, nao existe garantia tecnica honesta de risco zero. O criterio
correto e impedir promocao enquanto qualquer gate estiver incompleto ou
vermelho e manter rollback imediato para riscos residuais externos.
