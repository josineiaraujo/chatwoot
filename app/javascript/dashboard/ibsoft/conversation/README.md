# Ibsoft Conversation Presentation Patch

## Objetivo

Este patch ajusta a apresentacao operacional do status `pending` para a
operacao Ibsoft:

- exibe `pending` como `Automacao` nos filtros/listas operacionais;
- remove a acao manual de marcar uma conversa como `pending` nos menus de
  atendimento;
- substitui a aba visivel `Todas` por `Automacoes`, mantendo `Todas` acessivel
  em um menu de tres pontos;
- consulta a aba `Automacoes` como `assignee_type=all` e `status=pending`.
- exibe um identificador operacional `Protocolo` no formato
  `YYYYMMDD-accountId-conversationId`;
- adiciona filtro operacional por `Protocolo`, sem criar coluna ou mudar o
  contrato publico de conversa;
- apresenta a acao `resolved` como `Encerrar atendimento` nos pontos
  operacionais do atendimento.

As APIs, macros e telas de configuracao de automacao continuam usando o contrato
padrao do Chatwoot.

## Arquivos do patch

- `statusPresentation.js`: concentra labels, chaves e transformacoes de
  apresentacao do status `pending` e da aba operacional.
- `automationConversationStats.js`: busca a contagem de conversas em
  `Automacoes` usando a API oficial de meta de conversas.
- `statusStatsRefresh.js`: centraliza o criterio para recarregar contadores
  quando uma conversa entra ou sai do status `pending`.
- `protocol.js`: calcula o protocolo operacional a partir de `created_at`,
  `account_id` e `display_id` da conversa, e valida o formato usado pelo filtro.
- `app/services/ibsoft/conversation/protocol.rb`: concentra o parser backend do
  protocolo e o range UTC do dia usado nas consultas.
- `app/services/ibsoft/conversation/protocol_search.rb`: aplica busca por
  protocolo em relations de conversas sem gravar coluna nova no banco.
- `app/services/ibsoft/conversation/protocol_filter_payload.rb`: transforma o
  filtro privado `ibsoft_protocol` em filtros padrao de `display_id` e
  `created_at` antes do `FilterService` original processar a consulta.
- `components/OperationalChatTypeTabs.vue`: envolve o `ChatTypeTabs` original,
  troca a aba primaria `Todas` por `Automacoes` e adiciona o menu secundario
  para acessar `Todas`.

## Pontos de acoplamento no Chatwoot

- `app/javascript/dashboard/components/ChatList.vue`: conecta o componente de
  tabs Ibsoft e aplica os helpers para mapear `Automacoes` para
  `all + pending`.
- `app/javascript/dashboard/store/modules/conversations/actions.js`: aceita
  `pageFilterKey` como chave opcional de paginacao/lista, preservando o
  comportamento padrao quando a chave nao existe.
- `app/javascript/dashboard/store/modules/conversations/actions.js` e
  `helpers/actionHelpers.js`: aceitam `preserveConversationStats` como flag
  local de busca para que a aba `Automacoes` nao sobrescreva os contadores
  operacionais de `Minhas`, `Nao atribuidas` e `Todas`.
- `app/services/conversations/filter_service.rb`: possui apenas o ponto de
  acoplamento que delega a expansao do filtro de protocolo para o service
  Ibsoft.
- `app/services/search_service.rb` e `app/finders/conversation_finder.rb`:
  delegam buscas textuais em formato de protocolo para
  `Ibsoft::Conversation::ProtocolSearch`, mantendo a busca padrao do Chatwoot
  para os demais textos.
- `components-next/filter/provider.js`, `advancedFilterItems/index.js` e
  `filterHelpers.js`: registram o filtro `Protocolo` e mantem compatibilidade
  com custom views.
- Componentes de filtro/status/context menu importam helpers deste patch para
  trocar labels e esconder a acao manual de `pending`.
- `ConversationHeader.vue` e `ConversationCardExpanded.vue` usam o helper de
  protocolo para substituir a exibicao do identificador tecnico.
- Acoes de encerramento no header, menu contextual, command bar, modal de
  atributos obrigatorios e acoes em massa usam traducoes Ibsoft para apresentar
  `Encerrar atendimento`, preservando o status interno `resolved`.
- Mudancas locais de status feitas pelo header, menu contextual ou acoes em
  massa disparam refresh dos contadores quando envolvem `pending`, mantendo a
  badge `Automacoes` sincronizada com a lista.
- O modal de atalhos aceita `titleKey` opcional para que os atalhos de
  encerramento usem traducoes Ibsoft sem alterar traducoes globais do
  Chatwoot.
- Traducoes ficam em `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`.
- Mensagens Rails de atividade ficam em `config/locales/zz_ibsoft_conversation.*.yml`
  para sobrescrever traducoes sem editar os arquivos originais do Chatwoot.
- A chave `conversations.activity.status.open` em pt-BR e sobrescrita para
  `Conversa foi aberta por %{user_name}`, evitando o termo `reaberta`.

## Regras de manutencao

- Nao alterar controllers, models ou APIs Rails para este patch.
- Nao renomear o status real `pending`; a mudanca e apenas de apresentacao e de
  navegacao operacional.
- Nao renomear o status real `resolved`; a mudanca e apenas de apresentacao
  operacional como `Encerrar atendimento`.
- Nao tocar em telas de configuracao de automacoes, macros ou API publica para
  remover `pending`.
- Se o Chatwoot alterar `ChatList.vue` ou `ChatTypeTabs.vue`, revisar primeiro
  os pontos de conexao acima e manter a regra privada dentro desta pasta.

## Validacao

- `git diff --check`
- `node --check app/javascript/dashboard/ibsoft/conversation/statusPresentation.js`
- `node --check app/javascript/dashboard/ibsoft/conversation/automationConversationStats.js`
- `node --check app/javascript/dashboard/ibsoft/conversation/statusStatsRefresh.js`
- `node --check app/javascript/dashboard/ibsoft/conversation/protocol.js`
- `bundle exec rspec spec/services/search_service_spec.rb spec/finders/conversation_finder_spec.rb spec/controllers/api/v1/accounts/search_controller_spec.rb`
- ESLint deve ser executado quando `node_modules` estiver instalado.
