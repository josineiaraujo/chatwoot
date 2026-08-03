# Disparo de mensagens Ibsoft

## Objetivo

Criar uma base privada para envio individual ou em massa usando dados vindos do
ERP ativo da conta e canais WhatsApp Business Cloud ja configurados no ChatHub.

Nesta etapa, o modulo entrega a fundacao de backend e a primeira tela
operacional:

- tabelas minimas para grupos fixos, disparos e destinatarios;
- escolha inicial e explicita entre envio individual e envio em massa;
- selecao de destinatarios antes da escolha do template;
- selecao normalizada de telefone principal e telefone alternativo;
- preview de destinatarios a partir do ERP ativo;
- lookups normalizados de estados, cidades, planos e infraestrutura para IXC e
  SGP;
- buscas IXC e SGP por cliente, contratos/planos e concentradores;
- criacao e manutencao de grupos fixos;
- envio imediato sem passagem obrigatoria por rascunho;
- salvamento opcional de rascunhos para revisao e envio posterior;
- abertura do rascunho para revisao operacional;
- envio individual executado na propria requisicao e envio em massa distribuido
  em jobs independentes por destinatario;
- envio direto pela API da Meta como padrao, sem criar contato, contact inbox,
  conversa ou mensagem no Chatwoot;
- registro opcional em conversa, com possibilidade de encerrar a nova conversa
  depois do envio ou mante-la aberta;
- preservacao de uma conversa aberta e do agente que ja a atende;
- acompanhamento dos estados `accepted`, `sent`, `delivered`, `read`, `failed`
  e `uncertain` a partir do ID retornado pela Meta;
- tela administrativa guiada por etapas, com historico de disparos, escolha de
  origem, montagem de destinatarios e preparacao do envio;
- listagem de templates WhatsApp Cloud diretamente pela API da Meta, usando o
  canal selecionado;
- identificacao automatica de idioma, componentes e variaveis do template;
- testes automatizados com WebMock/mocks, sem chamadas reais para clientes,
  Meta, IXC ou SGP.

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
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/broadcast_deletions_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/lookups_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/recipients_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_broadcast/templates_controller.rb`

Services do modulo:

- `app/services/ibsoft/message_broadcast/phone_selector.rb`
- `app/services/ibsoft/message_broadcast/phone_selection.rb`
- `app/services/ibsoft/message_broadcast/recipient_search.rb`
- `app/services/ibsoft/message_broadcast/recipient_search_cache.rb`
- `app/services/ibsoft/message_broadcast/recipient_attributes_builder.rb`
- `app/services/ibsoft/message_broadcast/recipient_phone_candidates.rb`
- `app/services/ibsoft/message_broadcast/template_catalog.rb`
- `app/services/ibsoft/message_broadcast/template_button_variables.rb`
- `app/services/ibsoft/message_broadcast/template_parameter_builder.rb`
- `app/services/ibsoft/message_broadcast/template_content_renderer.rb`
- `app/services/ibsoft/message_broadcast/queue_broadcast.rb`
- `app/services/ibsoft/message_broadcast/broadcast_execution_claim.rb`
- `app/services/ibsoft/message_broadcast/broadcast_deletion.rb`
- `app/services/ibsoft/message_broadcast/recipient_delivery_claim.rb`
- `app/services/ibsoft/message_broadcast/recipient_sender.rb`
- `app/services/ibsoft/message_broadcast/broadcast_sender.rb`
- `app/services/ibsoft/message_broadcast/direct_recipient_delivery.rb`
- `app/services/ibsoft/message_broadcast/conversation_recipient_delivery.rb`
- `app/services/ibsoft/message_broadcast/meta_template_client.rb`
- `app/services/ibsoft/message_broadcast/rate_limiter.rb`
- `app/services/ibsoft/message_broadcast/broadcast_finalizer.rb`
- `app/services/ibsoft/message_broadcast/status_updater.rb`
- `app/services/ibsoft/message_broadcast/whatsapp_status_extension.rb`

Jobs do modulo:

- `app/jobs/ibsoft/message_broadcast/build_recipient_search_cache_job.rb`
- `app/jobs/ibsoft/message_broadcast/send_broadcast_job.rb`
- `app/jobs/ibsoft/message_broadcast/send_recipient_job.rb`
- `app/jobs/ibsoft/message_broadcast/dispatch_pending_job.rb`

Services ERP usados pelo modulo:

- `app/services/ibsoft/erp/normalized_customer.rb`
- `app/services/ibsoft/erp/customer_search_result.rb`
- `app/services/ibsoft/erp/adapters/registry.rb`
- `app/services/ibsoft/erp/adapters/ixc/client.rb`
- `app/services/ibsoft/erp/adapters/ixc/query_builder.rb`
- `app/services/ibsoft/erp/adapters/ixc/lookups.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_mapper.rb`
- `app/services/ibsoft/erp/adapters/ixc/client_batch_fetcher.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_search.rb`
- `app/services/ibsoft/erp/adapters/ixc/search/*`
- `app/services/ibsoft/erp/adapters/sgp/client.rb`
- `app/services/ibsoft/erp/adapters/sgp/customer_catalog.rb`
- `app/services/ibsoft/erp/adapters/sgp/customer_mapper.rb`
- `app/services/ibsoft/erp/adapters/sgp/lookups.rb`
- `app/services/ibsoft/erp/adapters/sgp/pppoe_catalog.rb`
- `app/services/ibsoft/erp/adapters/sgp/customer_search.rb`
- `app/services/ibsoft/erp/adapters/sgp/search/*`

## Estrutura frontend

Frontend isolado:

- `app/javascript/dashboard/ibsoft/messageBroadcast/api.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/BroadcastWorkspace.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/GroupEditorDialog.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/LookupMultiSelect.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/LookupSingleSelect.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/RecipientSelectionDialog.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/SearchModeMenu.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/RecipientTable.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/components/TemplatePreview.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/routes.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/views/Index.vue`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/BroadcastWorkspace.spec.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/GroupEditorDialog.spec.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/Index.spec.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/RecipientSelectionDialog.spec.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/RecipientTable.spec.js`
- `app/javascript/dashboard/ibsoft/messageBroadcast/specs/TemplatePreview.spec.js`

A previa visual do conteudo reutiliza o componente privado
`ibsoft/metaTemplates/components/WhatsAppTemplatePreview.vue`. O adaptador
`templateToDraft` converte o retorno da Meta para o contrato visual desse
componente. Essa dependencia entre modulos privados e explicita e restrita a
apresentacao: evita duplicar a representacao do WhatsApp e mantem a mesma
previa na criacao, edicao e preparacao do disparo, sem tocar no core do
Chatwoot nem alterar o contrato de envio.

A tela fica acessivel pelo menu principal como `Disparo de mensagens`, apenas
para administradores nesta etapa. Se nao houver ERP ativo na conta, a tela
exibe estado vazio e bloqueia a selecao de destinatarios.

O historico usa toda a largura disponivel do dashboard com espacamento lateral
responsivo. A criacao acontece em um workspace de tela cheia, cujo conteudo e
centralizado e limitado a `max-w-6xl`; isso separa claramente consulta e tarefa
sem alterar layouts centrais do Chatwoot. Formularios e detalhes continuam
legiveis em telas largas e se reorganizam pelos breakpoints definidos no proprio
modulo.

O novo envio segue cinco etapas, mantendo apenas as escolhas relevantes na
tela atual:

1. `Configuracao`: escolher envio individual ou em massa e o canal WhatsApp
   Business Cloud. Quando a conta possui apenas um canal compativel, ele e
   pre-selecionado sem impedir uma troca futura caso novos canais sejam criados.
2. `Destinatarios`: selecionar uma pessoa por busca direta no modo individual;
   no modo em massa, pesquisar e selecionar clientes ou usar grupos fixos.
3. `Conteudo`: pesquisar o template Meta, conferir a previa a direita, mapear
   variaveis e consultar o resumo abaixo do editor.
4. `Entrega`: enviar diretamente pela Meta, opcao padrao, ou registrar em
   conversa e escolher se novas conversas permanecem abertas.
5. `Revisao`: conferir escopo, destinatarios, canal, template, prioridade dos
   telefones e estrategia de entrega antes de enviar ou salvar como rascunho.

Fluxos complementares cobertos pela tela:

- historico de disparos/rascunhos em tabela responsiva de largura integral,
  ordenado do mais recente para o mais antigo e paginado no PostgreSQL, com
  limite configuravel de 10, 25, 30, 50 ou 100 registros por pagina. Contagem,
  limite, atualizacao e navegacao ficam reunidos em um unico rodape privado,
  sem alterar o paginador compartilhado do Chatwoot;
- atualizacao explicita do historico, selecao dos registros removiveis da pagina
  e exclusao individual ou em lote com confirmacao;
- exclusao permitida apenas para `draft`, `completed`, `failed` e `cancelled`.
  Registros `queued` e `running` sao bloqueados no frontend e novamente
  validados sob lock no backend. A exclusao em lote e atomica: se um item for
  invalido, estiver ativo ou pertencer a outra conta, nenhum item e removido;
- criacao de um novo disparo em workspace de tela cheia, mantendo o historico
  como pagina base e o mesmo padrao operacional usado pelo editor privado de
  templates Meta;
- navegacao progressiva entre etapas ja visitadas e confirmacao antes de fechar
  um disparo com selecoes ou configuracoes ainda nao salvas;
- identificacao do autor em cada disparo e visualizacao dos detalhes em modal;
- acao para iniciar novo disparo;
- escolha entre `Pesquisar e selecionar` e `Usar grupos` apenas no modo em
  massa;
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
- selecao em modal compacto, com contador sempre visivel e acoes distintas
  para selecionar a pagina atual ou todos os resultados do filtro;
- adicao explicita de clientes encontrados a lista de destinatarios;
- adicao de todos os resultados, lidos do snapshot Redis em paginas de ate 500
  registros e em lotes concorrentes limitados;
- carregamento de grupos fixos;
- selecao de um ou mais grupos para adicionar destinatarios;
- criacao de grupo fixo no mesmo modal de busca, usando os clientes marcados na
  pagina atual ou todos os resultados do filtro;
- edicao de grupos pelo icone de lapis em cada card, permitindo renomear,
  pesquisar e paginar integrantes, ajustar telefones, remover destinatarios e
  adicionar clientes da pagina atual ou de todas as paginas do filtro;
- configuracao do canal WhatsApp Business Cloud antes da selecao de
  destinatarios;
- carregamento dos templates disponiveis na Meta para o canal selecionado;
- preview do conteudo completo do template selecionado, incluindo componentes,
  idioma, status, categoria e botoes;
- identificacao automatica das variaveis do template;
- mapeamento das variaveis para campo do cliente ou valor fixo sem quebra de
  linha;
- disparo individual imediato e sincronizado para exatamente um destinatario;
- disparo em massa assincrono, com um job independente por destinatario;
- salvamento opcional do disparo como rascunho;
- abertura do rascunho a partir do historico;
- revisao de status por destinatario;
- envio do rascunho por job.

Na etapa de destinatarios, os blocos seguem fluxo vertical e usam toda a
largura util do conteudo: filtros, clientes encontrados e lista de
destinatarios. Os modos de busca ficam em menu segmentado centralizado para nao
serem confundidos com campos de formulario.

A busca e a selecao ficam em um modal menor que o workspace principal. O
usuario ve a quantidade selecionada durante toda a operacao e precisa escolher
explicitamente entre a pagina atual e todas as paginas. A mesma interface serve
para adicionar destinatarios ou criar um grupo, mas o nome do grupo e exibido
somente no segundo caso.

A lista final de destinatarios inicia com 10 registros por pagina e permite ao
usuario selecionar 10, 25, 50 ou 100. No modo individual, a selecao e exclusiva
e o usuario precisa escolher exatamente uma pessoa. A tabela oferece
busca por nome, cidade, estado ou telefone, filtro por disponibilidade de
telefone, identificacao e edicao dos telefones principal/alternativo e remocao.
A paginacao e
local porque os destinatarios selecionados ja pertencem ao rascunho em
construcao; isso evita novas chamadas ao ERP ao navegar nessa tabela.

## Banco de dados

Migration:

- `db/migrate/20260707130000_create_ibsoft_message_broadcast.rb`
- `db/migrate/20260709190000_add_template_variable_values_to_ibsoft_message_broadcast_recipients.rb`
- `db/migrate/20260801150000_add_delivery_modes_to_ibsoft_message_broadcast.rb`

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
- status operacional do disparo/destinatario;
- modo de despacho (`single` ou `bulk`);
- modo de entrega (`direct`, `close_after_send` ou `keep_open`);
- ID da mensagem retornado pela Meta;
- instantes de enfileiramento e inicio do processamento usados para recuperacao
  segura de jobs.

## Busca de destinatarios por ERP

`Ibsoft::Erp::Adapters::Registry` e o unico registro de providers do modulo. Ele
resolve o adapter de busca, os lookups e as capacidades visuais de cada ERP.
O frontend consome essas capacidades e nao precisa conhecer regras internas do
IXC ou SGP. Os dois providers devolvem o mesmo contrato
`Ibsoft::Erp::NormalizedCustomer`.

Como os ERPs nao oferecem todos os joins necessarios, as buscas usam processos
em etapas:

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
- payload bruto do ERP nao e salvo no Redis nem no banco;
- snapshots corrompidos sao descartados e reconstruidos.

As paginas seguintes e a acao de adicionar todos leem o mesmo snapshot. Uma
pagina comum le somente os blocos necessarios. A pesquisa em `Clientes
encontrados` percorre os blocos do snapshot e aceita nome, codigo do ERP,
documento, endereco, bairro, cidade, estado, CEP e telefones, com comparacao
sem diferenca entre maiusculas/minusculas ou acentos. O texto pesquisado nao
faz parte da chave base e nunca provoca nova consulta ao ERP.

Ao criar um grupo com `todas as paginas`, o frontend envia apenas o token do
snapshot e a pesquisa textual ativa. O backend valida que o snapshot pertence
a conta e a conexao ERP ativas, normaliza os membros e os grava em lotes dentro
da mesma transacao do grupo. Se o TTL tiver expirado, nenhuma parte do grupo e
persistida e o usuario deve executar a busca novamente. Para a pagina atual, o
frontend envia somente os membros marcados.

Assim, trocar de pagina, alterar a quantidade ou pesquisar nao repete a
pesquisa no ERP. Para adicionar outro provider, registre no
`Ibsoft::Erp::Adapters::Registry` um adapter com `call_all(mode:, filters:)`,
lookups normalizados e suas capacidades. O resultado deve usar
`Ibsoft::Erp::NormalizedCustomer`.

O limite operacional atual dos adapters e de 10.000 registros de origem por
busca. A construcao assincrona evita timeout HTTP, mas o limite continua
protegendo memoria, Redis e o ERP.

### Particularidades IXC

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

### Particularidades SGP

Autenticacao:

- reutiliza a conexao SGP ativa da conta;
- suporta o contrato `token_app` (`app` e `token`) e autenticacao basica;
- nenhum segredo e enviado ao frontend ou gravado no snapshot de busca.

Endpoints consultados:

- `POST /api/ura/clientes/` para clientes, contratos e servicos;
- `GET /api/ura/consultaplano/` para planos;
- `POST /api/ura/pops/` para POPs;
- `POST /api/ura/nas/list/` para NAS;
- `POST /ws/radius/radacct/list/all/` para sessoes PPPoE.

Busca direta:

- envia o nome ao SGP quando informado;
- percorre clientes em paginas de 100 e aplica localmente os demais filtros de
  cadastro;
- estado e cidade usam um catalogo normalizado derivado do snapshot de clientes
  e limitado a UFs brasileiras validas;
- `omitir_contratos` so e enviado quando os contratos podem ser descartados. O
  parametro e omitido quando contratos sao necessarios, pois algumas versoes do
  SGP interpretam `false` como verdadeiro.

Busca por contratos e planos:

- carrega clientes com contratos e servicos em paginas de 100;
- filtra localmente status de contrato, plano, estado, cidade e status do
  cliente;
- o status ativo do cliente e derivado dos contratos ativos (`1` e `7`, alem
  das representacoes textuais equivalentes);
- essa filtragem local evita depender do comportamento inconsistente de filtros
  com multiplos status observado entre versoes do SGP.

Busca por infraestrutura:

- POP e NAS sao lookups pesquisaveis;
- a porta do transmissor continua disponivel como filtro numerico;
- o adapter busca sessoes PPPoE em blocos e cruza primeiro por `servico_id`;
- quando o SGP nao devolve `servico_id`, o cruzamento usa o login PPPoE
  documentado;
- o resultado e deduplicado por cliente antes da normalizacao;
- campos exclusivos do IXC, como interface de transmissao e caixa FTTH, nao
  aparecem quando a conexao ativa e SGP.

O catalogo SGP e limitado e paginado; nao existe consulta individual por
cliente nem N+1. Lookups usam cache Rails por 15 minutos, isolado por conexao e
por sua data de atualizacao.

## Selecao de telefones

Services:

- `Ibsoft::MessageBroadcast::PhoneSelector`
- `Ibsoft::MessageBroadcast::RecipientPhoneCandidates`

Prioridade normalizada para IXC e SGP:

1. `whatsapp`;
2. `telefone_celular`;
3. `fone`.

Regras:

- numeros sao normalizados para formato E.164;
- duplicados sao removidos;
- o primeiro numero valido vira `primary_phone` e sempre e tentado primeiro;
- o segundo numero valido vira `fallback_phone` e mantem sua funcao de numero
  alternativo;
- destinatarios sem numero valido ficam inelegiveis para envio.

O telefone alternativo somente e usado quando:

- o telefone principal estiver ausente ou for invalido antes da chamada; ou
- a Meta rejeitar explicitamente o telefone principal com uma resposta HTTP
  `4xx`.

O telefone alternativo nunca e tentado depois de timeout, erro HTTP `5xx`,
resposta HTTP `2xx` sem ID de mensagem ou outra falha cujo resultado seja
incerto. Nesses casos, o destinatario fica com status `uncertain`, pois repetir
o envio poderia entregar a mesma mensagem duas vezes. Nao ha retry automatico.
Cada destinatario tenta no maximo uma vez cada numero elegivel, sem repetir
numeros iguais.

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
- `DELETE /broadcasts/:id`
- `DELETE /broadcasts/bulk_destroy`
- `POST /broadcasts/:id/send_broadcast`
- `GET /templates`
- `GET /capabilities`
- `GET /lookups/states`
- `GET /lookups/cities`
- `GET /lookups/plans`
- `GET /lookups/pops`
- `GET /lookups/transmitters`
- `POST /recipients/preview`

As rotas usam a conexao ERP ativa da conta. IXC e SGP implementam o mesmo
contrato de busca. `GET /capabilities` informa os modos e filtros suportados
pelo provider ativo, permitindo que a UI oculte opcoes que aquele ERP nao pode
executar.

`GET /broadcasts` aceita `page` e `per_page`, limita cada pagina a no maximo
100 registros e retorna `meta` com pagina atual, tamanho da pagina, total de
registros e total de paginas. A consulta e paginada no PostgreSQL e agrega a
contagem de destinatarios por pagina, sem carregar os destinatarios completos.

`DELETE /broadcasts/:id` e `DELETE /broadcasts/bulk_destroy` removem somente
disparos fora de processamento. O endpoint em lote recebe `ids` e opera em uma
transacao unica. Os registros privados de destinatarios sao removidos em lote;
conversas e mensagens nativas eventualmente referenciadas nao sao apagadas.

`POST /recipients/preview` aceita `page`, `limit`, `query` e `refresh`. O
frontend usa pagina de
10 itens por padrao para navegacao, permitindo selecionar 10, 25, 50 ou 100. O
backend limita cada resposta a 500 itens. A
resposta inclui `total`, `total_pages`, `has_more`, `search_token`, `cache_hit`
e o TTL do cache. Durante a construcao, a resposta usa HTTP 202 e
`status: building`; quando pronta, usa `status: ready`. `refresh` e enviado
somente na primeira requisicao de uma atualizacao explicita e nunca durante o
polling.

`GET /groups` retorna apenas os metadados e a contagem de membros para manter a
listagem leve. Durante a selecao para um disparo, a interface mostra somente os
grupos e a quantidade selecionada, sem expandir a lista de destinatarios.
Os membros do grupo sao carregados por `GET /groups/:id` apenas ao avancar no
fluxo ou ao abrir o `GroupEditorDialog`. A listagem nominal nao faz parte da
selecao: ela aparece somente no fluxo explicito de edicao, onde o salvamento
substitui a lista completa de integrantes de forma transacional por
`PATCH /groups/:id`.
`POST /groups` aceita uma lista explicita de `members` ou uma `selection` com
`scope: all`, `search_token` e a pesquisa textual opcional do snapshot Redis.

`GET /templates` recebe `inbox_id`, sincroniza os modelos pela API da Meta
usando o canal WhatsApp Cloud selecionado e devolve uma resposta normalizada
com `name`, `language`, `status`, `category`, `components` e `variables`. O
payload bruto da Meta nao e salvo nas tabelas do modulo; o modulo apenas usa o
cache nativo `channel_whatsapp.message_templates` mantido pelo Chatwoot.
Modelos de ordem (`ORDER_DETAILS` e `ORDER_STATUS`) nao fazem parte do catalogo
de disparos, pois exigem uma estrutura transacional propria e nao sao
compativeis com o mapeamento generico de destinatarios e variaveis desta tela.

Variaveis de texto do cabecalho e do corpo sao armazenadas com chave interna
escopada pelo componente quando a Meta reutiliza o mesmo identificador, por
exemplo `header:1` e `body:1`. O parametro enviado para a Meta continua sendo
`1` dentro do respectivo componente. Isso impede que o valor do cabecalho
sobrescreva o valor do corpo sem alterar o contrato do provedor.

Cabecalhos `IMAGE`, `VIDEO` e `DOCUMENT` geram o campo obrigatorio de URL de
midia na etapa de mensagem. A interface aceita somente URL publica HTTP(S),
mostra a midia na previa quando o navegador consegue acessa-la e salva apenas a
configuracao necessaria ao disparo. No envio, o modulo converte esse campo para
`processed_params.header.media_url` e `processed_params.header.media_type`,
contrato ja consumido pelo processador WhatsApp. Nao foi criada tabela nem
dependencia nova para esse suporte.

Os botoes aprovados no template tambem sao preservados na previa. Botoes
estaticos (`QUICK_REPLY`, telefone e URL sem variavel) nao exigem configuracao
adicional no disparo. Uma URL dinamica pode receber o valor de um campo do
cliente ou um valor fixo; o valor representa somente a parte variavel definida
no template. Botoes `COPY_CODE` exigem um valor fixo de ate 15 caracteres.

O catalogo guarda `button_type` e `button_index` apenas nas configuracoes das
variaveis que precisam de valor em tempo de envio. O builder produz uma lista
esparsa em `processed_params.buttons`, preservando a posicao original mesmo
quando os botoes anteriores sao estaticos. Assim, o processador WhatsApp nativo
do Chatwoot gera os componentes Meta com o indice correto sem qualquer novo
acoplamento ao core. Rascunhos antigos sem `button_index` continuam usando o
comportamento sequencial anterior.

`POST /broadcasts` aceita `dispatch_mode` (`single` ou `bulk`) e
`conversation_mode` (`direct`, `close_after_send` ou `keep_open`). Um envio
individual exige `source_type: selection` e exatamente um destinatario. Tanto a
criacao imediata quanto `POST /broadcasts/:id/send_broadcast` passam por uma
transicao atomica de `draft` para `queued`.

No modo `single`, `BroadcastSender` executa o unico destinatario dentro da
requisicao e devolve o resultado final. No modo `bulk`, `SendBroadcastJob`
adquire o disparo e agenda um `SendRecipientJob` por destinatario. Assim, uma
mensagem lenta nao bloqueia todas as demais e mais processos Sidekiq podem
consumir a fila `medium` em paralelo.

No modo `direct`, `MetaTemplateClient` monta o template e chama diretamente o
endpoint `/messages` da Meta. Nenhum `Contact`, `ContactInbox`, `Conversation`
ou `Message` e criado. No modo de conversa,
`ConversationRecipientDelivery` reutiliza uma conversa aberta do mesmo contato
e canal ou cria as entidades necessarias. A mensagem usa o agente que iniciou o
disparo como autor.

### Concorrencia e claims de envio

O fluxo usa transicoes condicionais atomicas no PostgreSQL e nao mantem
transacao aberta durante chamadas externas:

- `QueueBroadcast` adquire somente `draft -> queued`; dois cliques ou duas
  requisicoes concorrentes agendam apenas um job;
- `BroadcastExecutionClaim` adquire somente `queued -> running`; um job
  duplicado nao executa um broadcast que outro worker ja iniciou;
- `RecipientDeliveryClaim` adquire somente `pending/queued -> processing`;
  apenas um worker pode enviar para cada destinatario;
- destinatarios ja aceitos ou em estado terminal nunca sao readquiridos;
- `RateLimiter` limita globalmente por canal e segundo usando Redis, inclusive
  quando existem varios processos ou servidores Sidekiq;
- `BroadcastFinalizer` encerra o disparo somente quando nao existe destinatario
  pendente, enfileirado ou em processamento;
- `DispatchPendingJob`, executado a cada minuto pela fila `scheduled_jobs`,
  recupera disparos e destinatarios que ficaram enfileirados sem job;
- um destinatario em `processing` por mais de 15 minutos vira `uncertain` e nao
  e reenviado automaticamente.

Essas regras protegem contra cliques repetidos, jobs duplicados, reinicio de
containers e workers concorrentes em uma instalacao com autoscaling. Nao existe
retry automatico de entrega. A recuperacao repoe apenas trabalho que ainda nao
comecou; trabalho interrompido depois do inicio fica incerto para evitar
duplicidade no cliente.

Antes de criar uma nova conversa, o `RecipientSender` procura uma conversa
aberta do mesmo contato no mesmo canal. Se ela existir, o disparo e enviado
nessa conversa e a configuracao `close_after_send` e ignorada para esse
destinatario. Essa regra evita encerrar um atendimento que ja estava em curso
entre agente e cliente e preserva o agente que ja estava atribuido.

Ao enfileirar um disparo, o controller grava `sent_by` com o agente atual. O
`RecipientSender` usa esse usuario como autor da mensagem, inclusive quando
reaproveita uma conversa aberta atribuida a outro agente. Se `sent_by` estiver
vazio por compatibilidade com rascunhos antigos, o fallback e `created_by`.

O ID retornado pela Meta e salvo em `meta_message_id`. O initializer privado
`config/initializers/ibsoft_message_broadcast.rb` adiciona uma extensao ao
processamento de status do WhatsApp sem editar essa classe nativa. Webhooks
posteriores avancam o destinatario para `sent`, `delivered` ou `read`, ou o
marcam como `failed`. Eventos atrasados nao rebaixam um status mais novo.

Variaveis operacionais opcionais:

- `IBSOFT_MESSAGE_BROADCAST_RATE_LIMIT_PER_SECOND`: limite por canal e segundo;
  padrao `10`, minimo `1`, maximo `80`.
- `IBSOFT_MESSAGE_BROADCAST_META_TIMEOUT_SECONDS`: timeout da chamada Meta;
  padrao `20`, minimo `5`, maximo `60`.

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
- `config/schedule.yml`: registra o job privado de recuperacao a cada minuto.
- `config/initializers/ibsoft_message_broadcast.rb`: aplica via `prepend` o
  adaptador privado de status da Meta ao service WhatsApp durante o boot.

As regras de despacho, fallback, criacao opcional de conversa, rate limit e
status continuam em classes `Ibsoft::MessageBroadcast`. Nao houve alteracao em
models nativos, campanhas nativas ou canais para implementar este fluxo.

## Testes

Backend:

```bash
RAILS_ENV=test bundle exec rspec \
  spec/services/ibsoft/message_broadcast \
  spec/jobs/ibsoft/message_broadcast \
  spec/services/ibsoft/erp/adapters/ixc/customer_search_spec.rb \
  spec/services/ibsoft/erp/adapters/sgp/customer_search_spec.rb \
  spec/requests/api/v1/accounts/ibsoft/message_broadcast \
  spec/models/ibsoft/message_broadcast
```

Os testes de IXC, SGP e Meta usam WebMock. Eles nao chamam os ERPs reais, nao
chamam a Meta real, nao alteram dados externos e nao enviam mensagens para
clientes.

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
- Destinatarios `uncertain` exigem verificacao operacional. Reenvio automatico
  nao deve ser introduzido sem idempotencia garantida pela Meta.
- O envio individual ocorre dentro da requisicao e pode durar ate o timeout da
  Meta. Ele e limitado a um destinatario justamente para manter esse custo
  previsivel; lotes sempre devem usar workers.
- O rate limit padrao e uma protecao tecnica, nao uma garantia contratual de
  throughput da Meta. Alteracoes devem considerar os limites efetivos do WABA e
  do numero usado pelo canal.
