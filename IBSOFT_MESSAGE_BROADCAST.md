# Disparo de mensagens Ibsoft

## Objetivo

Criar uma base privada para envio de mensagens em massa usando dados vindos do
ERP ativo da conta e canais WhatsApp ja configurados no ChatHub.

Nesta etapa, o modulo entrega a fundacao de backend e a primeira tela
operacional:

- tabelas minimas para grupos fixos, disparos e destinatarios;
- selecao normalizada de telefone principal e telefone de fallback;
- preview de destinatarios a partir do ERP ativo;
- lookups IXC para estados, cidades, planos e concentradores;
- buscas IXC por cliente, contratos/planos e concentradores;
- criacao e manutencao de grupos fixos;
- envio imediato sem passagem obrigatoria por rascunho;
- salvamento opcional de rascunhos para revisao e envio posterior;
- abertura do rascunho para revisao operacional;
- envio assincrono por job proprio, usando o envio nativo de template WhatsApp
  Cloud do Chatwoot;
- criacao de conversa/mensagem por destinatario, com opcao de encerrar a
  conversa automaticamente ou mante-la aberta;
- tela administrativa guiada por etapas, com historico de disparos, escolha de
  origem, montagem de destinatarios e preparacao de rascunho;
- listagem de templates WhatsApp Cloud diretamente pela API da Meta, usando o
  canal selecionado;
- identificacao automatica de idioma, componentes e variaveis do template;
- testes automatizados com WebMock/mocks, sem chamadas reais para clientes,
  Meta ou IXC.

## Estrutura backend

Models:

- `app/models/ibsoft/message_broadcast/group.rb`
- `app/models/ibsoft/message_broadcast/group_member.rb`
- `app/models/ibsoft/message_broadcast/broadcast.rb`
- `app/models/ibsoft/message_broadcast/recipient.rb`

Controllers:

- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/base_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/groups_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/broadcasts_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/lookups_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/recipients_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/templates_controller.rb`

Services do modulo:

- `app/services/ibsoft/message_broadcast/phone_selector.rb`
- `app/services/ibsoft/message_broadcast/phone_selection.rb`
- `app/services/ibsoft/message_broadcast/recipient_search.rb`
- `app/services/ibsoft/message_broadcast/recipient_search_cache.rb`
- `app/services/ibsoft/message_broadcast/template_catalog.rb`
- `app/services/ibsoft/message_broadcast/template_parameter_builder.rb`
- `app/services/ibsoft/message_broadcast/template_content_renderer.rb`
- `app/services/ibsoft/message_broadcast/queue_broadcast.rb`
- `app/services/ibsoft/message_broadcast/broadcast_execution_claim.rb`
- `app/services/ibsoft/message_broadcast/recipient_delivery_claim.rb`
- `app/services/ibsoft/message_broadcast/recipient_sender.rb`
- `app/services/ibsoft/message_broadcast/broadcast_sender.rb`

Jobs do modulo:

- `app/jobs/ibsoft/message_broadcast/build_recipient_search_cache_job.rb`
- `app/jobs/ibsoft/message_broadcast/send_broadcast_job.rb`

Services ERP usados pelo modulo:

- `app/services/ibsoft/erp/normalized_customer.rb`
- `app/services/ibsoft/erp/customer_search_result.rb`
- `app/services/ibsoft/erp/adapters/ixc/client.rb`
- `app/services/ibsoft/erp/adapters/ixc/query_builder.rb`
- `app/services/ibsoft/erp/adapters/ixc/lookups.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_mapper.rb`
- `app/services/ibsoft/erp/adapters/ixc/client_batch_fetcher.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_search.rb`
- `app/services/ibsoft/erp/adapters/ixc/search/*`

## Estrutura frontend

Frontend isolado:

- `app/javascript/dashboard/ibsoft/messageBroadcast/api.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/LookupMultiSelect.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/LookupSingleSelect.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/SearchModeMenu.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/RecipientTable.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/routes.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/views/Index.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/Index.spec.js`

A tela fica acessivel pelo menu principal como `Disparo de mensagens`, apenas
para administradores nesta etapa. Se nao houver ERP ativo na conta, a tela
exibe estado vazio e bloqueia a selecao de destinatarios.

O conteudo da pagina segue o mesmo contrato responsivo usado pelos modulos
nativos de Contatos e Relatorios: largura fluida ate `max-w-5xl`, centralizacao
horizontal e espacamento lateral `px-6`. O fundo continua ocupando a area
disponivel do dashboard, enquanto formularios, historico e detalhes permanecem
legiveis em telas largas e se reorganizam pelos breakpoints ja definidos no
proprio modulo. Esse contrato fica inteiramente em `Index.vue`, sem alterar
layouts centrais do Chatwoot.

Fluxos cobertos pela tela:

- historico inicial de disparos/rascunhos;
- acao para iniciar novo disparo;
- escolha entre `Pesquisar e selecionar` e `Usar grupos`;
- busca direta de clientes;
- busca por contratos e planos;
- busca por concentradores;
- seletores pesquisaveis de selecao unica para estado e cidade, com cidade
  dependente do estado selecionado;
- carregamento automatico dos catalogos IXC de planos de acesso e
  concentradores quando o usuario entra nesses modos de busca;
- seletores compactos pesquisaveis para planos de acesso e concentradores,
  mantendo a lista em dropdown rolavel e evitando ocupar a tela inteira;
- seletores de lookup limitados a largura da coluna responsiva, com truncamento
  do rotulo quando o valor selecionado for maior que o espaco disponivel;
- inputs e seletores compartilham `box-border`, `w-full` e margem inferior
  zerada para manter alinhamento e largura visual identicos nas grades;
- lista paginada de clientes encontrados;
- controle de 10, 25, 50 ou 100 itens por pagina nas listas de clientes
  encontrados e de destinatarios;
- total exato de clientes normalizados e navegacao entre todas as paginas do
  resultado armazenado no Redis;
- selecao parcial ou da pagina atual;
- adicao explicita de clientes encontrados a lista de destinatarios;
- adicao de todos os resultados, lidos do snapshot Redis em paginas de ate 500
  registros e em lotes concorrentes limitados;
- carregamento de grupos fixos;
- selecao de um ou mais grupos para adicionar destinatarios;
- salvamento da selecao atual como grupo fixo;
- configuracao do canal WhatsApp;
- carregamento dos templates disponiveis na Meta para o canal selecionado;
- preview do conteudo completo do template selecionado, incluindo componentes,
  idioma, status, categoria e botoes;
- identificacao automatica das variaveis do template;
- mapeamento das variaveis para campo do cliente ou valor fixo sem quebra de
  linha;
- disparo imediato, criando o registro operacional diretamente no estado
  `queued` e agendando o job de envio;
- salvamento opcional do disparo como rascunho;
- abertura do rascunho a partir do historico;
- revisao de status por destinatario;
- envio do rascunho por job.

Na etapa de destinatarios, os blocos seguem fluxo vertical e usam toda a
largura util do conteudo: filtros, clientes encontrados e lista de
destinatarios. Os modos de busca ficam em menu segmentado centralizado para nao
serem confundidos com campos de formulario.

A lista final de destinatarios inicia com 10 registros por pagina e permite ao
usuario selecionar 10, 25, 50 ou 100. Ela oferece
busca por nome, cidade, estado ou telefone, filtro por disponibilidade de
telefone, edicao dos telefones principal/alternativo e remocao. A paginacao e
local porque os destinatarios selecionados ja pertencem ao rascunho em
construcao; isso evita novas chamadas ao ERP ao navegar nessa tabela.

## Banco de dados

Migration:

- `db/migrate/20260707130000_create_ibsoft_message_broadcast.rb`
- `db/migrate/20260709190000_add_template_variable_values_to_ibsoft_message_broadcast_recipients.rb`

Tabelas:

- `ibsoft_message_broadcast_groups`
- `ibsoft_message_broadcast_group_members`
- `ibsoft_message_broadcasts`
- `ibsoft_message_broadcast_recipients`

Nao existe coluna de payload bruto do ERP. Apenas dados operacionais realmente
necessarios sao persistidos:

- identificador externo do cliente;
- nome;
- telefone principal;
- telefone de fallback;
- valores de variaveis realmente usados pelo template para aquele destinatario;
- cidade;
- estado;
- status operacional do disparo/destinatario.

## Busca IXC

O IXC nao oferece joins. Por isso, as buscas usam processos em etapas:

### Snapshot paginado no Redis

O endpoint de preview nao devolve apenas a primeira pagina do IXC. Na primeira
consulta para uma combinacao de modo e filtros, o service
`Ibsoft::MessageBroadcast::RecipientSearch` adquire um lock e agenda
`Ibsoft::MessageBroadcast::BuildRecipientSearchCacheJob` na fila `medium`. O
frontend recebe `status: building` e consulta novamente ate o snapshot ficar
pronto, sem manter uma requisicao web bloqueada durante a leitura do ERP.

Regras do cache:

- TTL fixo de 15 minutos;
- chave SHA-256 deterministica por versao, conta, conexao ERP, data de
  atualizacao da conexao, modo e filtros canonicos;
- isolamento entre contas e entre conexoes ERP;
- arrays de filtros sao canonizados para que a ordem de IDs nao gere outro
  snapshot;
- lock distribuido com token de propriedade e expiracao de 10 minutos;
- somente um job pode construir uma mesma chave por vez;
- o job confirma novamente a propriedade do lock antes de publicar o snapshot
  ou registrar uma falha, impedindo que um job atrasado sobrescreva uma
  construcao mais recente;
- clientes divididos em blocos de 250 registros, gravados em pipeline;
- cada bloco e comprimido com `Zlib` e codificado em Base64;
- metadados sao gravados por ultimo, evitando expor snapshot parcial;
- somente campos normalizados necessarios para selecao e envio sao mantidos;
- o snapshot mantem apenas identificador, nome, documento, status, endereco,
  cidade, estado, CEP e telefones principal/fallback;
- payload bruto do IXC nao e salvo no Redis nem no banco;
- snapshots corrompidos sao descartados e reconstruidos.

As paginas seguintes e a acao de adicionar todos leem o mesmo snapshot. Uma
pagina comum le somente os blocos necessarios. A pesquisa em `Clientes
encontrados` percorre os blocos do snapshot e aceita nome, codigo do ERP,
documento, endereco, bairro, cidade, estado, CEP e telefones, com comparacao
sem diferenca entre maiusculas/minusculas ou acentos. O texto pesquisado nao
faz parte da chave base e nunca provoca nova consulta ao IXC.

Assim, trocar de pagina, alterar a quantidade ou pesquisar nao repete a
pesquisa no IXC. O contrato e extensivel por
provider em `Ibsoft::MessageBroadcast::RecipientSearch::SEARCH_ADAPTERS`; um
novo ERP deve fornecer `call_all(mode:, filters:)` e devolver clientes no
contrato `Ibsoft::Erp::NormalizedCustomer`.

O limite operacional atual da camada IXC e de 10.000 registros de origem por
busca. A construcao assincrona evita timeout HTTP, mas o limite continua
protegendo memoria, Redis e o ERP.

### Busca direta

Tabela principal:

- `cliente`

Filtros:

- `cliente.razao` com operador `L`;
- `cliente.endereco` com operador `L`;
- `cliente.bairro` com operador `L`;
- `cliente.cep` com operador `=`;
- `cliente.cidade` com operador `=`;
- `cliente.uf` com operador `=`;
- `cliente.ativo` com operador `=`.

A leitura completa percorre `cliente` em paginas de 100 registros. Nao existe
consulta individual por cliente.

Lookup de estados:

- `uf` e filtrado na origem por `uf.id_pais = 2`, mantendo somente registros
  vinculados ao Brasil no IXC.
- quando o usuario pesquisa por estado/sigla, o filtro de pais continua sendo
  enviado em `grid_param`.
- consultas internas por IDs de UF tambem mantem `uf.id_pais = 2`, para evitar
  enriquecer clientes com estados de outro pais.
- o campo de estado na UI usa selecao unica pesquisavel e consulta este lookup
  com debounce.
- o campo de cidade na UI usa selecao unica pesquisavel, consulta `cidade`
  dentro do estado selecionado e tambem aplica debounce.

### Busca por contratos e planos

Lookups:

- `vd_contratos` lista os planos de acesso diretamente do IXC para selecao do
  usuario. O campo de busca no frontend apenas filtra esse catalogo; o filtro
  aplicado na busca usa os IDs retornados pelo IXC.

Tabela inicial:

- `cliente_contrato`

Filtros:

- `cliente_contrato.status`;
- `cliente_contrato.status_internet`;
- `cliente_contrato.id_vd_contrato`;
- `cliente_contrato.bloqueio_automatico`.
- `cliente.uf`, aplicado na etapa de busca dos clientes;
- `cliente.cidade`, aplicado na etapa de busca dos clientes.

Depois da consulta:

1. coletar `id_cliente`;
2. remover duplicados;
3. buscar clientes por `cliente.id IN (...)` em lotes de 100;
4. aplicar `cliente.ativo = S/N`, `cliente.uf` e `cliente.cidade` quando esses
   filtros de cadastro estiverem definidos;
5. paginar depois dos filtros de cadastro para evitar paginas vazias causadas
   por contratos de clientes que nao correspondem ao estado/cidade.

Observacao IXC:

- filtros de contrato com apenas um valor, como `status = A` ou
  `status_internet = A`, devem usar operador `=`;
- o IXC pode retornar HTML invalido quando esses campos sao enviados com
  operador `IN` e apenas um valor;
- listas reais, como multiplos planos de acesso, continuam usando `IN`.
- embora `cliente_contrato` possua o campo `cidade`, muitos contratos retornam
  `cidade = 0`; por isso filtros de estado e cidade nesta busca usam os campos
  oficiais do cadastro do cliente (`cliente.uf` e `cliente.cidade`).

### Busca por concentradores

- `radusuarios`
- `radpop_radio`

Filtros suportados sobre logins PPPoE:

- `radusuarios.id_concentrador`;
- `radusuarios.id_transmissor`;
- `radusuarios.interface_transmissao`;
- `radusuarios.id_caixa_ftth`;
- `radusuarios.id_porta_transmissor`.

Filtro por concentrador:

- concentrador nao e POP;
- o usuario informa os IDs de concentrador diretamente, separados por virgula;
- esses IDs sao aplicados em `radusuarios.id_concentrador`.

Filtro por POP:

- `radusuarios` nao aceita `id_pop` diretamente no IXC testado;
- `radpop` lista os POPs diretamente do IXC para selecao pesquisavel do
  usuario;
- para filtrar por POP, o modulo consulta `radpop_radio.id_pop`, coleta os IDs
  dos transmissores e aplica esses IDs em `radusuarios.id_transmissor`;
- quando POP e transmissor sao informados ao mesmo tempo, o filtro usa a
  intersecao entre os transmissores selecionados e os transmissores encontrados
  para os POPs.

Lookup de transmissores:

- `radpop_radio` lista os transmissores OLT diretamente do IXC para selecao do
  usuario;
- os demais filtros de infraestrutura sao preenchidos como lista de IDs
  separados por virgula, porque ainda nao temos catalogos confiaveis para eles.

Observacoes:

- a rota documentada de NAS/concentradores (`radauth_nas`) respondeu vazia no
  ambiente local testado;
- a rota `radnas` tambem respondeu, mas sem registros;
- por isso a busca operacional usa os campos disponiveis em `radusuarios`.

Lookups:

- `radpop` lista POPs diretamente do IXC para selecao do usuario;
- o campo de busca no frontend apenas filtra esse catalogo; a busca usa os IDs
  retornados pelo IXC em `pop_ids`.

Busca:

1. consultar `radusuarios.id_concentrador IN (...)`;
2. aplicar `radusuarios.ativo = S`;
3. coletar `id_cliente`;
4. remover duplicados;
5. buscar clientes por `cliente.id IN (...)` em lotes de 100.

## Selecao de telefones

Service:

- `Ibsoft::MessageBroadcast::PhoneSelector`

Prioridade para IXC:

1. `whatsapp`;
2. `telefone_celular`;
3. `fone`.

Regras:

- numeros sao normalizados para formato E.164;
- duplicados sao removidos;
- o primeiro numero valido vira `primary_phone`;
- o segundo numero valido vira `fallback_phone`;
- destinatarios sem numero valido ficam inelegiveis para envio.

Na primeira versao de envio real, o fallback e usado quando:

- nao houver telefone principal; ou
- o envio pelo telefone principal nao retornar id de mensagem da Meta.

Nao ha retry automatico nesta etapa. Cada destinatario tenta no maximo o
telefone principal e, se existir, o telefone de fallback.

## API

Namespace:

```text
/api/v1/accounts/:account_id/ibsoft/message_broadcast
```

Rotas iniciais:

- `GET /groups`
- `GET /groups/:id`
- `POST /groups`
- `PATCH /groups/:id`
- `DELETE /groups/:id`
- `GET /broadcasts`
- `GET /broadcasts/:id`
- `POST /broadcasts`
- `POST /broadcasts/:id/send_broadcast`
- `GET /templates`
- `GET /lookups/states`
- `GET /lookups/cities`
- `GET /lookups/plans`
- `GET /lookups/pops`
- `GET /lookups/transmitters`
- `POST /recipients/preview`

As rotas usam a conexao ERP ativa da conta. Nesta primeira etapa, apenas IXC
esta implementado para busca de destinatarios.

`POST /recipients/preview` aceita `page`, `limit`, `query` e `refresh`. O
frontend usa pagina de
10 itens por padrao para navegacao, permitindo selecionar 10, 25, 50 ou 100. O
backend limita cada resposta a 500 itens. A
resposta inclui `total`, `total_pages`, `has_more`, `search_token`, `cache_hit`
e o TTL do cache. Durante a construcao, a resposta usa HTTP 202 e
`status: building`; quando pronta, usa `status: ready`. `refresh` e enviado
somente na primeira requisicao de uma atualizacao explicita e nunca durante o
polling.

`GET /templates` recebe `inbox_id`, sincroniza os modelos pela API da Meta
usando o canal WhatsApp Cloud selecionado e devolve uma resposta normalizada
com `name`, `language`, `status`, `category`, `components` e `variables`. O
payload bruto da Meta nao e salvo nas tabelas do modulo; o modulo apenas usa o
cache nativo `channel_whatsapp.message_templates` mantido pelo Chatwoot.

`POST /broadcasts/:id/send_broadcast` muda o rascunho para `queued`, marca
destinatarios pendentes como `queued` e agenda
`Ibsoft::MessageBroadcast::SendBroadcastJob`. O job usa
`Ibsoft::MessageBroadcast::BroadcastSender` e
`Ibsoft::MessageBroadcast::RecipientSender` para criar conversa e mensagem de
template por destinatario. A mensagem e criada com `source_id` temporario para
evitar o envio duplicado pelo callback nativo; em seguida o service chama o
envio de template do `Channel::Whatsapp` e troca o `source_id` pelo id retornado
pela Meta.

### Concorrencia e claims de envio

O fluxo usa transicoes condicionais atomicas no PostgreSQL e nao mantem
transacao aberta durante chamadas externas:

- `QueueBroadcast` adquire somente `draft -> queued`; dois cliques ou duas
  requisicoes concorrentes agendam apenas um job;
- `BroadcastExecutionClaim` adquire somente `queued -> running`; um job
  duplicado nao executa um broadcast que outro worker ja iniciou;
- `RecipientDeliveryClaim` adquire somente `pending/queued -> processing`;
  apenas um worker pode enviar para cada destinatario;
- destinatarios em estado terminal (`sent`, `failed` ou `skipped`) nunca sao
  readquiridos;
- uma excecao inesperada depois do claim marca o destinatario e o broadcast
  como `failed`.

Essas regras protegem contra cliques repetidos, jobs duplicados e workers
concorrentes em uma instalacao com autoscaling. Nao existe retry automatico.
Se o processo for encerrado de forma abrupta depois que a Meta aceitar a
mensagem e antes da confirmacao no banco, o destinatario pode permanecer
`processing`. Ele deve ser reconciliado manualmente; nao e reenviado
automaticamente porque isso poderia duplicar a mensagem no cliente.

Antes de criar uma nova conversa, o `RecipientSender` procura uma conversa
aberta do mesmo contato no mesmo canal. Se ela existir, o disparo e enviado
nessa conversa e a configuracao `close_after_send` e ignorada para esse
destinatario. Essa regra evita encerrar um atendimento que ja estava em curso
entre agente e cliente.

Ao enfileirar um disparo, o controller grava `sent_by` com o agente atual. O
`RecipientSender` usa esse usuario como autor da mensagem, inclusive quando
reaproveita uma conversa aberta atribuida a outro agente. Se `sent_by` estiver
vazio por compatibilidade com rascunhos antigos, o fallback e `created_by`.

## Permissao

Nesta etapa, as rotas aceitam apenas administradores da conta:

- `Current.account_user&.administrator?`

Quando a UI completa for criada, a permissao pode ser refinada para um papel
Ibsoft proprio de disparo.

## Pontos de acoplamento no Chatwoot original

- `config/routes.rb`: registra o namespace API privado
  `ibsoft/message_broadcast`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend privada `ibsoft_message_broadcast`.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona o
  item de menu `Disparo de mensagens` para administradores.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos da tela.

Nao houve alteracao em models nativos do Chatwoot, services de mensagens,
campanhas nativas ou canais.

## Testes

Backend:

```bash
RAILS_ENV=test bundle exec rspec \
  spec/services/ibsoft/message_broadcast/broadcast_execution_claim_spec.rb \
  spec/services/ibsoft/message_broadcast/broadcast_sender_spec.rb \
  spec/services/ibsoft/message_broadcast/phone_selector_spec.rb \
  spec/services/ibsoft/message_broadcast/queue_broadcast_spec.rb \
  spec/services/ibsoft/message_broadcast/recipient_delivery_claim_spec.rb \
  spec/services/ibsoft/message_broadcast/recipient_search_spec.rb \
  spec/services/ibsoft/message_broadcast/recipient_sender_spec.rb \
  spec/services/ibsoft/erp/adapters/ixc/customer_search_spec.rb \
  spec/requests/api/v1/accounts/ibsoft/message_broadcast/templates_spec.rb \
  spec/requests/api/v1/accounts/ibsoft/message_broadcast \
  spec/models/ibsoft/message_broadcast
```

Os testes de IXC e Meta usam WebMock. Eles nao chamam o IXC real, nao chamam a
Meta real, nao alteram dados no ERP e nao enviam mensagens para clientes.

Frontend:

```bash
./node_modules/.bin/vitest run \
  app/javascript/dashboard/ibsoft/messageBroadcast/specs \
  --no-cache --no-coverage --logHeapUsage
```

No ambiente Docker local, executar dentro do container `vite`.

## Riscos e proximas evolucoes

- Pesquisas textuais sobre snapshots proximos de 10.000 clientes precisam ler
  todos os blocos. Se esse volume se tornar frequente, a proxima evolucao deve
  ser um indice de busca separado, medido antes de introduzir outra estrutura.
- Grupos continuam fixos nesta etapa. Grupos dinamicos devem reutilizar o
  contrato de busca, sem persistir payload bruto do ERP.
- Nao existe retry automatico de destinatario; essa politica continua fora do
  escopo da primeira versao.
- O estado `processing` deixado por encerramento abrupto do worker exige
  reconciliacao manual antes de qualquer futura politica de retry.
