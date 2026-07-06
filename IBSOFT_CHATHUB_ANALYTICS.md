# Analytics ChatHub Ibsoft

Este documento descreve o modulo privado de dashboards operacionais do
ChatHub. O objetivo e manter a funcionalidade isolada, auditavel e simples de
reaplicar apos atualizacoes do Chatwoot oficial.

## Objetivo

- Servir como Pagina inicial do ChatHub, carregada automaticamente ao acessar o
  modulo.
- Fornecer um dashboard do agente com indicadores pessoais de atendimento.
- Fornecer um dashboard de supervisao para administradores e supervisores
  Ibsoft.
- Consolidar dados de conversas, eventos de relatorio do Chatwoot e auditoria
  da distribuicao Ibsoft sem alterar o fluxo original de atendimento.

## Escopo funcional

Dashboard do agente:

- atendimentos abertos atribuidos ao agente;
- tempo medio de resposta;
- atendimentos encerrados no periodo;
- redistribuicoes saindo do agente;
- visao por departamento;
- tendencia diaria de resposta;
- sugestoes operacionais simples.

Dashboard de supervisao:

- conversas abertas e nao atribuidas;
- tempo medio de primeira resposta;
- tempo medio de resolucao;
- total e taxa de redistribuicoes;
- ranking de agentes por atendimentos;
- ranking de agentes com redistribuicoes;
- ranking de maior tempo medio de primeira resposta;
- saude por departamento;
- volume diario;
- distribuicao por hora do dia;
- sugestoes operacionais.

Home ChatHub:

- decide automaticamente qual dashboard carregar pela permissao da conta atual;
- usuarios administradores ou com
  `ibsoft_conversation_distribution_supervise` entram inicialmente na visao de
  supervisao/equipe;
- usuarios com permissao de supervisao podem alternar entre `Meu painel` e
  `Painel da equipe` sem sair da Home;
- agentes comuns veem a visao individual do agente;
- usuarios com permissao de supervisao tambem veem o botao `Supervisao`, que
  abre a tela operacional de supervisao de atendimentos.

Semantica de metricas:

- Redistribuicoes nao devem ser apresentadas como percentual, porque a razao
  pode passar de 100% quando existem varias redistribuicoes para poucos
  atendimentos. A UI deve exibir razao operacional, por exemplo:
  `13 redistribuicoes / 1 atendimento`.
- O ranking de redistribuicoes por agente representa atendimentos que sairam da
  fila do agente por redistribuicao automatica, usando `previous_assignee_id` do
  log Ibsoft. Ele nao representa atendimentos que o agente recebeu por
  redistribuicao.
- Quando o denominador da razao for menor que o limite minimo visual definido no
  frontend, a UI deve marcar `amostra insuficiente` em vez de sugerir uma taxa
  confiavel.
- Duracoes exibidas ao usuario devem passar pelo formatter unico do dashboard,
  evitando misturar horas em cards com minutos crus em insights.
- Contagens exibidas em captions devem usar pluralizacao local, nao apenas
  interpolar o numero em texto fixo.

## Backend

Arquivos privados:

- `app/controllers/api/v1/accounts/ibsoft/chathub_analytics/base_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/chathub_analytics/dashboards_controller.rb`
- `app/services/ibsoft/chathub_analytics/date_range.rb`
- `app/services/ibsoft/chathub_analytics/base_dashboard.rb`
- `app/services/ibsoft/chathub_analytics/agent_dashboard.rb`
- `app/services/ibsoft/chathub_analytics/supervisor_dashboard.rb`
- `app/services/ibsoft/chathub_analytics/permission.rb`
- `config/locales/ibsoft_chathub_analytics.pt_BR.yml`
- `config/locales/ibsoft_chathub_analytics.en.yml`

Endpoints:

- `GET /api/v1/accounts/:account_id/ibsoft/chathub_analytics/agent_dashboard`
- `GET /api/v1/accounts/:account_id/ibsoft/chathub_analytics/supervisor_dashboard`

Filtros aceitos:

- `period`: `last_7_days`, `last_30_days` ou `custom`;
- `since`: data inicial quando `period=custom`;
- `until`: data final quando `period=custom`;
- `inbox_id`: canal de comunicacao;
- `team_id`: departamento.

Fontes de dados:

- `Conversation`: backlog aberto, conversas nao atribuidas, conversas criadas e
  conversas por agente/time.
- `ReportingEvent`: tempos nativos do Chatwoot, incluindo resposta, primeira
  resposta e resolucao.
- `Ibsoft::ConversationDistribution::EventLog`: redistribuicoes geradas pelo
  modulo privado de distribuicao.

Banco de dados:

- Este modulo nao cria tabelas novas.
- Ele depende das tabelas nativas do Chatwoot e da tabela
  `ibsoft_conversation_distribution_event_logs`.

Permissoes:

- O dashboard do agente pode ser lido por usuarios autenticados da conta.
- O dashboard de supervisao pode ser lido por administradores ou usuarios com a
  permissao privada `ibsoft_conversation_distribution_supervise`.

## Frontend

Arquivos privados:

- `app/javascript/dashboard/ibsoft/chathubAnalytics/api.js`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/routes.js`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/views/Index.vue`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/components/MetricCard.vue`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/components/BarList.vue`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/components/TrendBars.vue`
- `app/javascript/dashboard/ibsoft/chathubAnalytics/components/SuggestionList.vue`

Rotas frontend:

- `ibsoft_chathub_home`: rota principal em
  `/app/accounts/:accountId/chathub`.
- `ibsoft_chathub_analytics`: rota legada em
  `/app/accounts/:accountId/chathub-analytics`, mantida apenas como
  redirecionamento para a Home.

Padrao de UI:

- usa componentes e tokens do dashboard;
- usa `IbsoftSelect` compartilhado para filtros;
- exibe cards, barras horizontais, tendencia compacta e heatmap horario;
- apresenta loading, erro e estado vazio;
- todo texto exibido fica em `ibsoftTheme.json`.

## Pontos de acoplamento no Chatwoot original

- `config/routes.rb`: registra as rotas API do namespace
  `ibsoft/chathub_analytics`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend `ibsoft_chathub_home` e o redirecionamento legado
  `ibsoft_chathub_analytics`.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: registra o
  item de menu `Pagina inicial` do ChatHub como primeiro item, antes de
  `Atencao`. O painel de supervisao nao aparece como item direto no menu
  principal.
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftTheme.json`: registra textos
  em portugues.
- `app/javascript/dashboard/i18n/locale/en/ibsoftTheme.json`: registra textos em
  ingles.

Esses pontos devem continuar pequenos. Regras de negocio, consultas, formatacao
dos dados e componentes visuais ficam dentro do modulo Ibsoft.

## Testes

Backend:

- `spec/services/ibsoft/chathub_analytics/agent_dashboard_spec.rb`
- `spec/services/ibsoft/chathub_analytics/supervisor_dashboard_spec.rb`
- `spec/requests/api/v1/accounts/ibsoft/chathub_analytics/dashboards_spec.rb`

Frontend:

- `app/javascript/dashboard/ibsoft/chathubAnalytics/specs/Index.spec.js`

Comandos recomendados:

```bash
bundle exec rspec spec/services/ibsoft/chathub_analytics spec/requests/api/v1/accounts/ibsoft/chathub_analytics/dashboards_spec.rb
bundle exec rubocop app/services/ibsoft/chathub_analytics app/controllers/api/v1/accounts/ibsoft/chathub_analytics spec/services/ibsoft/chathub_analytics spec/requests/api/v1/accounts/ibsoft/chathub_analytics/dashboards_spec.rb
pnpm exec vitest run app/javascript/dashboard/ibsoft/chathubAnalytics/specs/Index.spec.js
pnpm exec eslint app/javascript/dashboard/ibsoft/chathubAnalytics app/javascript/dashboard/routes/dashboard/dashboard.routes.js app/javascript/dashboard/components-next/sidebar/Sidebar.vue
```

## Riscos e cuidados

- Os indicadores dependem da qualidade dos `ReportingEvent` gerados pelo
  Chatwoot. Se um canal nao gerar evento de resposta ou resolucao, o dashboard
  mostra zero para esse indicador.
- Rankings sao limitados no service para evitar respostas grandes.
- O ranking `Maiores tempos de primeira resposta` e limitado a 10 agentes; os
  demais rankings operacionais usam o limite geral do service.
- Periodos customizados muito amplos podem consultar muitos eventos. Para
  producao com alto volume, considerar materializacao ou cache por periodo.
- O modulo e somente leitura. Ele nao deve alterar conversas, atribuicoes,
  politicas ou configuracoes.

## Orientacao para atualizar upstream

1. Resolver conflitos primeiro nos conectores listados acima.
2. Conferir se `ReportingEvent`, `Conversation` e os getters frontend usados
   continuam com os mesmos contratos.
3. Rodar os testes e lint recomendados.
4. Conferir manualmente a rota `/app/accounts/:accountId/chathub` em usuario
   agente e usuario supervisor/admin. Conferir tambem que a rota legada
   `/app/accounts/:accountId/chathub-analytics` redireciona para a Home.
