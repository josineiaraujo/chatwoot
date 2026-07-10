# Configuracoes globais ChatHub

## Objetivo

Centralizar configuracoes globais da operacao ChatHub que nao pertencem a um
canal de comunicacao ou departamento especifico.

Nesta fase, a tela controla:

- visualizacao propria em cards para canais de comunicacao, usando stores e
  rotas nativas sem editar o componente original de canais;
- modal por canal para configurar encaminhamento de conversas paradas na
  automacao, delegando regra e persistencia ao modulo de distribuicao Ibsoft;
- desativacao silenciosa da atribuicao automatica nativa do Chatwoot ao abrir
  as regras do canal, evitando conflito com as politicas Ibsoft;
- atalhos integrados para as telas nativas de departamentos, robos,
  integracoes e conta, alem da tela privada de ERPs, renderizadas dentro do
  menu ChatHub apenas para administradores;
- modal pos-login para agentes;
- percentual minimo de atendimentos obrigatorios ao entrar;
- minimo obrigatorio de atendimentos ao entrar;
- bloqueio de fechamento do modal quando houver obrigatorios;
- janela de estabilizacao pos-login para agentes que retornaram apos longo
  periodo offline;
- acesso via perfil/permissao Ibsoft para usuarios nao administradores.

## Estrutura

Backend isolado:

- `app/models/ibsoft/chathub_settings/account_setting.rb`
- `app/models/ibsoft/chathub_settings/agent_presence_state.rb`
- `app/services/ibsoft/chathub_settings/settings_resolver.rb`
- `app/services/ibsoft/chathub_settings/configuration_validator.rb`
- `app/services/ibsoft/chathub_settings/permission.rb`
- `app/services/ibsoft/chathub_settings/agent_presence_tracker.rb`
- `app/controllers/api/v1/accounts/ibsoft/chathub_settings/`

Frontend isolado:

- `app/javascript/dashboard/ibsoft/chathubSettings/api.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/components/AutomationHandoffPolicyModal.vue`
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`
- `app/javascript/dashboard/ibsoft/chathubSettings/defaults.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/routes.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue`

Banco de dados:

- `ibsoft_chathub_settings`
- `ibsoft_chathub_agent_presence_states`

Tabela legada removida:

- `ibsoft_chathub_settings_managers`: removida por migration de limpeza. O
  controle de acesso da tela passou para perfis/permissoes.

## Configuracao

A configuracao fica em `ibsoft_chathub_settings.config`, separada por conta.

Formato atual:

```json
{
  "agent_entry_assignment": {
    "enabled": true,
    "required_percentage": 20,
    "minimum_required": 1,
    "block_close_when_required": true
  },
  "login_stabilization": {
    "enabled": false,
    "offline_threshold_minutes": 60,
    "window_minutes": 10,
    "max_assignments_during_window": 1,
    "minimum_online_agents_to_disable": 2
  }
}
```

## Modal pos-login

O modulo de distribuicao usa
`Ibsoft::ConversationDistribution::AgentEntryAssignmentPolicy` para calcular os
atendimentos obrigatorios do modal.

O calculo considera apenas o total de conversas disponiveis para o agente:

```text
obrigatorios = ceil(total_disponivel * required_percentage / 100)
obrigatorios = max(obrigatorios, minimum_required)
obrigatorios = min(obrigatorios, total_disponivel)
```

Esse calculo define somente o minimo que o agente precisa assumir ao entrar.
Se o agente quiser selecionar mais atendimentos, inclusive todos os disponiveis,
o sistema deve permitir.

Nao ha divisao pelo numero de agentes. A lista continua ordenada por
`waiting_since`, priorizando clientes que aguardam ha mais tempo.

## Estabilizacao pos-login

O watchdog Ibsoft chama `AgentPresenceTracker` a cada rodada para manter um
snapshot privado da presenca dos agentes.

Quando `login_stabilization.enabled=true`, o
`AgentStabilizationFilter` reduz os agentes disponiveis para a distribuicao
automatica quando:

- o agente esta online;
- voltou de um periodo offline maior ou igual a
  `offline_threshold_minutes`;
- ainda esta dentro de `window_minutes` desde o retorno;
- ja recebeu `max_assignments_during_window` atendimentos na janela;
- a quantidade de agentes elegiveis online ainda e menor que
  `minimum_online_agents_to_disable`.

Se todos os agentes elegiveis estiverem bloqueados pela estabilizacao, a
conversa continua sem atribuicao e sera avaliada na rodada seguinte.

## Permissao

A permissao privada e:

`ibsoft_chathub_settings_manage`

Administradores sempre acessam. Usuarios nao administradores precisam estar em
um perfil Ibsoft que contenha essa permissao.

As secoes integradas que renderizam tela de gestao de canais, departamentos,
robos, integracoes e conta ficam restritas a administradores, pois as rotas
nativas correspondentes exigem `administrator`. Isso evita que a tela privada
ChatHub contorne permissoes do core.

## Pontos de acoplamento

- `config/routes.rb`: registra API `ibsoft/chathub_settings`.
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: registra a
  rota frontend.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: adiciona o
  item de menu quando o usuario possui permissao, sempre ao final da lista
  principal. O mesmo ponto de conexao oculta visualmente os itens nativos de
  configuracao `Conta`, `Agente`, `Times`, `Canais de comunicacao`, `Robos` e
  `Integracoes` do menu padrao, pois essas entradas passam a ser centralizadas
  na tela privada ChatHub. As rotas nativas permanecem ativas para uso pelos
  atalhos internos.
- `app/views/api/v1/models/_user.json.jbuilder`: usa
  `Ibsoft::PermissionRegistry` para expor permissoes privadas.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: textos da UI.
- `app/services/ibsoft/conversation_distribution/agent_assignment_preview.rb`:
  consome a configuracao global para calcular obrigatorios.
- `app/services/ibsoft/conversation_distribution/assignment_executor.rb`:
  passa agentes elegiveis pelo filtro de estabilizacao.
- `app/services/ibsoft/conversation_distribution/watchdog_runner.rb`: atualiza
  snapshot privado de presenca antes de cada rodada.

Integracao com telas de configuracao:

- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`
  declara os imports assincronos das secoes integradas para conta, ERPs,
  canais, departamentos, robos e integracoes. O id tecnico de departamentos
  continua `teams`, seguindo o contrato nativo do Chatwoot, mas a UI exibe
  `Departamentos`.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`
  renderiza canais em cards usando `inboxes/getInboxes`, `inboxes/delete` e
  rotas nativas `settings_inbox_new` e `settings_inbox_show`. Tambem abre o
  `AutomationHandoffPolicyModal.vue` para configurar, por canal, regras de
  distribuicao e encaminhamento de automacoes paradas.
- `app/javascript/dashboard/ibsoft/chathubSettings/components/AutomationHandoffPolicyModal.vue`
  usa a action nativa `inboxes/updateInbox` para desativar silenciosamente
  `enable_auto_assignment` quando o modal e aberto e o canal ainda estiver com
  atribuicao automatica nativa ligada. Nao cria controller, rota ou tabela
  adicional para essa correcao. A UI exibe apenas um LED discreto de status,
  sem texto explicativo visivel.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/CollaboratorsPage.vue`
  oculta a secao nativa de atribuicao automatica para evitar que o usuario
  reative manualmente a distribuicao do Chatwoot enquanto a operacao usa as
  politicas Ibsoft.
- `app/javascript/dashboard/ibsoft/chathubSettings/views/Index.vue` sincroniza
  a secao ativa com `?section=...`. Isso preserva a secao atual quando o
  usuario abre uma rota nativa de configuracao e volta pelo navegador.
- Os componentes originais em `dashboard/routes/dashboard/settings/**` nao sao
  modificados para essa integracao. Times, robos, integracoes e conta
  continuam usando seus indices nativos; canais usam componente Ibsoft proprio
  e mantem navegacao para as rotas nativas do Chatwoot.

## Testes

- `spec/models/ibsoft/chathub_settings`
- `spec/services/ibsoft/chathub_settings`
- `spec/requests/api/v1/accounts/ibsoft/chathub_settings`
- `spec/services/ibsoft/conversation_distribution/agent_entry_assignment_policy_spec.rb`
- `spec/services/ibsoft/conversation_distribution/agent_assignment_preview_spec.rb`
- `spec/services/ibsoft/conversation_distribution/agent_assignment_claimer_spec.rb`
- `spec/services/ibsoft/conversation_distribution/assignment_executor_spec.rb`
- `app/javascript/dashboard/ibsoft/chathubSettings/specs/defaults.spec.js`
- `app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js`
