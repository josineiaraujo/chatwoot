# Ibsoft Conversation Presentation Patch

## Objetivo

Este patch ajusta a apresentacao operacional do status `pending` para a
operacao Ibsoft:

- exibe `pending` como `Automacao` nos filtros/listas operacionais;
- apresenta a aba operacional `unassigned` como `Fila`, sem alterar o valor
  interno, as APIs ou os textos tecnicos de configuracao;
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
- impede resposta publica antes de o agente assumir uma conversa sem
  responsavel ou ainda mantida em automacao;
- permite que outros agentes colaborem em conversas abertas atribuidas a um
  agente humano sem substituir o responsavel atual;
- permite notas privadas sem assumir a conversa e preserva o rascunho enquanto
  a atribuicao ou a retomada e confirmada.

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
- `replyAssignmentGuard.js`: concentra a matriz de decisao para bloquear
  respostas publicas, sem acoplar a regra ao componente nativo do composer.
- `components/ReplyAssignmentGuardBanner.vue`: executa explicitamente a
  atribuicao e, quando necessario, a abertura da conversa. A acao confirma o
  estado atualizado na store antes de liberar o composer.

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
- Eventos em tempo real continuam atualizando `Minhas` e `Nao atribuidas`
  mesmo quando `Automacoes` esta selecionada. Nesse caso, os contadores
  operacionais usam o ultimo status normal selecionado, sem substituir o
  recorte por `pending`.
- O contador de `Automacoes` ignora respostas antigas e preserva o ultimo valor
  valido quando uma consulta de atualizacao falha. Atualizacoes consecutivas
  sao agrupadas por debounce, com espera maxima, para evitar uma consulta de
  contagem por evento realtime em contas movimentadas.
- A exclusao local de uma conversa dispara uma atualizacao completa dos
  contadores no escopo atual.
- O modal de atalhos aceita `titleKey` opcional para que os atalhos de
  encerramento usem traducoes Ibsoft sem alterar traducoes globais do
  Chatwoot.
- Traducoes ficam em `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`.
- Mensagens Rails de atividade ficam em `config/locales/zz_ibsoft_conversation.*.yml`
  para sobrescrever traducoes sem editar os arquivos originais do Chatwoot.
- A chave `conversations.activity.status.open` em pt-BR e sobrescrita para
  `Conversa foi aberta por %{user_name}`, evitando o termo `reaberta`.
- `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`
  conecta o guard privado ao editor e aos caminhos de texto, anexo, audio e
  template. Este e o unico ponto novo no core para a protecao de resposta; o
  `ReplyBoxBanner.vue` original, as stores e as APIs nativas permanecem
  intocados.

## Regra de assumir antes de responder

- Conversa `open` atribuida a um agente humano: resposta liberada normalmente;
  o autor da mensagem participa sem substituir o responsavel atual.
- Conversa `open` atribuida a um bot: exige assumir o atendimento.
- Conversa `open` sem agente: exige a acao explicita `Assumir atendimento`.
- Conversa `pending` atribuida ao agente atual: exige apenas marcar como
  aberta.
- Conversa `pending` sem agente ou atribuida a outra pessoa: atribui primeiro
  e abre em seguida.
- Nota privada: permanece disponivel sem alterar responsavel ou status.
- Falha na atribuicao ou na abertura: o composer continua bloqueado e o texto
  salvo no rascunho nao e removido.
- O bloqueio tambem protege colagem de arquivo, gravacao de audio, templates e
  a chamada final de envio, evitando corrida entre a interface e eventos
  realtime.

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
- `pnpm test app/javascript/dashboard/ibsoft/conversation/specs/replyAssignmentGuard.spec.js app/javascript/dashboard/ibsoft/conversation/specs/ReplyAssignmentGuardBanner.spec.js app/javascript/dashboard/ibsoft/conversation/specs/ReplyBoxAssignmentGuard.spec.js`
- `bundle exec rspec spec/services/search_service_spec.rb spec/finders/conversation_finder_spec.rb spec/controllers/api/v1/accounts/search_controller_spec.rb`
- ESLint deve ser executado quando `node_modules` estiver instalado.
