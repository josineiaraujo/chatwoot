# Auditoria de integracao do Chatwoot v4.17.1

Este documento define o gate de regressao para integrar o Chatwoot `v4.17.1`
na camada privada Ibsoft. Ele nao autoriza publicacao por si so. A promocao
para producao depende de todos os gates deste documento passarem no commit
integrado final.

## Escopo auditado

- Base privada auditada: `9fa78c1c702b`.
- Tag oficial: `v4.17.1`, commit `e194a693e2db`.
- Base oficial atual da camada privada: `v4.16.2`.
- Commits oficiais no intervalo: 201.
- Arquivos alterados pelo upstream: 2.049.
- Commits existentes sobre `v4.16.2` na camada privada: 101.
- Arquivos modificados pelos dois lados: 79.
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
semantica quando estiverem entre os 79 arquivos compartilhados. Merge limpo
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

O pacote oficial `@chatwoot/utils` `0.0.57` ainda converte uma data simples de
forma incorreta em fusos negativos. A protecao privada em `filterHelpers.js`
deve permanecer ate existir correcao oficial equivalente.

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

### Dependencias frontend

O upstream substitui `@scmmishra/pico-search` por
`@chatwoot/pico-search`. Todo import privado deve ser migrado; atualmente o
ponto conhecido e
`app/javascript/dashboard/ibsoft/chathubSettings/components/ChannelCardsPanel.vue`.
Uma busca global e um build de producao sao obrigatorios antes da promocao.

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

## Gates obrigatorios depois do merge

### Gate 1: arvore e dependencias

- Nenhum conflito, marcador ou arquivo nao rastreado relacionado ao merge.
- `git diff --check` sem erros.
- `pnpm install --force --frozen-lockfile --shamefully-hoist` com Node 24,
  enquanto `postcss-import` nao for dependencia direta do projeto.
- Nenhum import restante de `@scmmishra/pico-search`.
- `bundle check` com Ruby 3.4.4.
- Revisao manual dos 79 arquivos compartilhados, nao apenas dos 15 conflitos.

### Gate 2: banco

- Preparar banco vazio com `RAILS_ENV=test bundle exec rails db:prepare`.
- Aplicar migrations em copia sanitizada do banco de producao.
- Conferir `db:migrate:status` e `db:abort_if_pending_migrations`.
- Verificar colunas privadas recentes, `ai_assignee_type`, indices e foreign
  keys.
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
- Migrations executadas antes da troca dos processos Rails e Sidekiq.
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
