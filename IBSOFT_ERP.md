# Integracoes ERP Ibsoft

## Objetivo

Criar uma camada privada para configurar integracoes com ERPs externos, de
forma escalavel para varios provedores e com apenas uma conexao ativa por conta.

Nesta primeira etapa, o modulo entrega:

- tela administrativa dentro de `Configuracoes de canais e departamentos`;
- cadastro, edicao, ativacao e remocao de conexoes ERP;
- suporte inicial aos provedores IXC Provedor e SGP;
- suporte a autenticacao `basic` para IXC;
- suporte a autenticacao `basic` e `token_app` para SGP;
- persistencia de credenciais sem expo-las no payload da API;
- teste de conexao usando listagem de clientes com limite de 1 registro, sem
  criar ou alterar dados no ERP.

Etapa complementar para disparo de mensagens:

- cliente HTTP IXC isolado;
- buscas normalizadas de clientes;
- lookups de estados, cidades, planos e concentradores;
- busca direta por cadastro;
- busca por contratos e planos;
- busca por concentradores via PPPoE ativo;
- leitura paginada e busca final de clientes em lotes por `cliente.id IN (...)`;
- normalizacao de clientes para contrato comum consumido por modulos futuros.

## Estrutura

Backend isolado:

- `app/models/ibsoft/erp/connection.rb`
- `app/controllers/api/v1/accounts/ibsoft/erp/base_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/erp/connections_controller.rb`
- `app/services/ibsoft/erp/connection_tester.rb`
- `app/services/ibsoft/erp/connection_test_result.rb`
- `app/services/ibsoft/erp/adapters/base_adapter.rb`
- `app/services/ibsoft/erp/adapters/ixc_adapter.rb`
- `app/services/ibsoft/erp/adapters/sgp_adapter.rb`
- `app/services/ibsoft/erp/normalized_customer.rb`
- `app/services/ibsoft/erp/customer_search_result.rb`
- `app/services/ibsoft/erp/adapters/ixc/client.rb`
- `app/services/ibsoft/erp/adapters/ixc/query_builder.rb`
- `app/services/ibsoft/erp/adapters/ixc/lookups.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_mapper.rb`
- `app/services/ibsoft/erp/adapters/ixc/client_batch_fetcher.rb`
- `app/services/ibsoft/erp/adapters/ixc/customer_search.rb`
- `app/services/ibsoft/erp/adapters/ixc/search/*`

Frontend isolado:

- `app/javascript/dashboard/ibsoft/erp/api.js`
- `app/javascript/dashboard/ibsoft/erp/providerConfig.js`
- `app/javascript/dashboard/ibsoft/erp/views/Index.vue`

Testes:

- `spec/factories/ibsoft/erp/connections.rb`
- `spec/models/ibsoft/erp/connection_spec.rb`
- `spec/requests/api/v1/accounts/ibsoft/erp/connections_spec.rb`
- `app/javascript/dashboard/ibsoft/erp/specs/providerConfig.spec.js`
- `app/javascript/dashboard/ibsoft/erp/specs/Index.spec.js`

## Banco de dados

Migration:

- `db/migrate/20260707120000_create_ibsoft_erp_connections.rb`

Tabela:

- `ibsoft_erp_connections`

Campos principais:

- `account_id`: conta proprietaria da configuracao;
- `name`: nome interno da conexao;
- `provider`: provedor tecnico, como `ixc` ou `sgp`;
- `auth_type`: tipo de autenticacao, como `basic` ou `token_app`;
- `base_url`: URL base do ERP;
- `active`: define a conexao padrao da conta;
- `credentials`: credenciais da conexao;
- `settings`: configuracoes adicionais futuras;
- `last_tested_at` e `last_test_status`: reservados para teste de conexao.

Indices:

- nome unico por conta/provedor;
- apenas uma conexao ativa por conta.

## Credenciais

O model usa `encrypts :credentials` quando a criptografia do Chatwoot estiver
configurada. O payload publico retorna apenas:

- `credentials_configured`;
- `credential_keys`;
- metadados da conexao.

As credenciais brutas nao sao retornadas para o frontend.

Ao editar uma conexao, campos sensiveis em branco sao ignorados para preservar
os valores ja configurados.

## Permissao

As rotas API do modulo aceitam somente administradores da conta:

- `Current.account_user&.administrator?`

A tela fica dentro das secoes integradas de configuracao ChatHub, que tambem
sao exibidas apenas para administradores.

## API

Namespace:

```text
/api/v1/accounts/:account_id/ibsoft/erp/connections
```

Rotas:

- `GET /connections`: lista provedores e conexoes da conta;
- `GET /connections/:id`: exibe uma conexao;
- `POST /connections`: cria uma conexao;
- `PATCH /connections/:id`: atualiza uma conexao;
- `POST /connections/:id/test_connection`: testa a conexao;
- `DELETE /connections/:id`: remove uma conexao.

## Teste de conexao

O teste de conexao e propositalmente somente leitura.

IXC Provedor:

- endpoint: `GET /webservice/v1/cliente`;
- cabecalho: `ixcsoft: listar`;
- payload: consulta por `cliente.id >= 1` com `rp: 1`.

SGP:

- endpoint: `POST /api/ura/clientes/`;
- autenticacao: `basic` ou `token_app`, conforme a conexao configurada;
- payload: `limit: 1`, `offset: 0`, `omitir_contratos: true` e
  `omitir_titulos: true`.

O resultado atualiza `last_tested_at` e `last_test_status` na conexao para
facilitar auditoria visual na tela administrativa.

## Busca normalizada IXC

A API do IXC aceita operadores como `=`, `L`, `IN` e `grid_param`, mas nao
oferece joins. Por isso, a camada privada executa buscas por etapas e entrega
um contrato comum `Ibsoft::Erp::NormalizedCustomer`.

Modos implementados:

- `direct`: pesquisa diretamente em `cliente`;
- `contracts`: pesquisa em `cliente_contrato`, deduplica `id_cliente` e busca
  os clientes finais;
- `concentrators`: pesquisa em `radusuarios` por concentradores ativos,
  deduplica `id_cliente` e busca os clientes finais.

Lookups implementados:

- `uf`;
- `cidade`;
- `vd_contratos`;
- `radpop`.

Nenhuma dessas operacoes escreve no IXC.

## Pontos de acoplamento no Chatwoot original

- `config/routes.rb`: registra o namespace API `ibsoft/erp`.
- `config/routes.rb`: registra tambem rotas do modulo dependente
  `ibsoft/message_broadcast`, que usa a conexao ERP ativa para lookups e
  preview de destinatarios.
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  adiciona a secao `erp` no menu administrativo de configuracoes ChatHub.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos da tela.
- `IBSOFT_CUSTOMIZATIONS.md`: inventario raiz das customizacoes.

Nao foi adicionada associacao ao model nativo `Account`; o controller consulta
`Ibsoft::Erp::Connection.where(account: Current.account)` para evitar tocar no
core.

## Evolucao planejada

Proximas camadas devem continuar isoladas:

- `app/services/ibsoft/erp/active_connection_resolver.rb`;
- contratos para busca de clientes, telefones, cidades, CEPs e campos usados
  em templates.

Modulos futuros, como mensagens em massa, devem depender apenas de services
Ibsoft de ERP, nunca diretamente das tabelas ou controllers.

## Testes recomendados

Backend:

```bash
bundle exec rspec spec/models/ibsoft/erp/connection_spec.rb spec/requests/api/v1/accounts/ibsoft/erp/connections_spec.rb
```

Frontend:

```bash
pnpm exec vitest run app/javascript/dashboard/ibsoft/erp/specs/providerConfig.spec.js app/javascript/dashboard/ibsoft/erp/specs/Index.spec.js app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js
```
