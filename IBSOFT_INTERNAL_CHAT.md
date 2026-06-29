# Ibsoft Internal Chat

Este documento descreve o modulo privado de chat interno acoplado ao Chatwoot.
Ele deve ser usado por pessoas e agentes de IA antes de alterar, expandir ou
reacoplar qualquer parte desta feature.

## Objetivo

O chat interno permite comunicacao entre agentes dentro do dashboard do
Chatwoot, sem misturar essa conversa com `Conversation`, `Inbox`, `Contact` ou
`Message` do atendimento a clientes.

O modulo suporta:

- chats diretos entre dois agentes;
- salas com nome, membros e imagem de capa;
- envio de texto, imagens, videos, audios e arquivos;
- atualizacao em tempo real via Action Cable;
- contagem de chats com mensagens novas;
- leitura por sala;
- permissao por participante;
- remocao de membro com bloqueio imediato a novas mensagens e anexos;
- endpoints protegidos para anexos e previews.

## Principios de arquitetura

- Codigo privado fica sob namespace `Ibsoft::InternalChat` no backend.
- Codigo privado de dashboard fica em `app/javascript/dashboard/ibsoft/internalChat`.
- O core do Chatwoot deve receber apenas pequenos pontos de conexao.
- Regras de negocio nao devem entrar em modelos centrais como `Conversation`,
  `Message`, `Inbox`, `Account` ou `User`.
- Textos exibidos ao usuario ficam em arquivos de traducao.
- Componentes devem usar tokens/classes de tema do Chatwoot, sem cores fixas.
- Toda nova funcionalidade deve ter teste proporcional ao risco.

## Estrutura geral

### Backend

O backend fica isolado em:

- `app/controllers/api/v1/accounts/ibsoft/internal_chat`
- `app/models/ibsoft/internal_chat`
- `app/services/ibsoft/internal_chat`
- `app/policies/ibsoft/internal_chat`
- `config/locales/ibsoft_internal_chat.*.yml`
- `db/migrate/20260510000000_create_ibsoft_internal_chat.rb`

### Frontend

O frontend fica isolado em:

- `app/javascript/dashboard/ibsoft/internalChat`
- `app/javascript/dashboard/i18n/locale/*/ibsoftInternalChat.json`

### Banco de dados

O modulo usa tabelas proprias:

- `ibsoft_internal_chat_rooms`
- `ibsoft_internal_chat_memberships`
- `ibsoft_internal_chat_messages`
- `ibsoft_internal_chat_attachments`

Nao usa tabelas nativas de conversas com clientes para armazenar o chat interno.

## Dominio

### Room

Representa uma sala ou chat direto.

- `room`: sala nomeada, com membros, capa e permissoes de gestao.
- `direct`: chat direto entre dois agentes, sem nome proprio.

### Membership

Representa a participacao de um usuario em uma sala/chat.

Armazena:

- usuario;
- sala;
- papel interno (`member` ou `admin`);
- ultima mensagem lida;
- data de ultima leitura.

### Message

Representa uma mensagem interna.

Armazena:

- sala;
- remetente;
- conteudo textual;
- tipo;
- metadados;
- exclusao logica.

### Attachment

Representa arquivo anexado a uma mensagem interna.

Importante:

- o payload nao deve expor URL direta do ActiveStorage;
- o acesso deve passar pelo controller protegido de anexos;
- previews devem usar endpoint proprio;
- permissao deve ser sempre derivada da sala.

## Permissoes

Regra atual:

- usuario da conta pode criar sala;
- apenas participante pode ver sala/chat;
- apenas participante pode enviar mensagem;
- apenas criador da sala pode adicionar/remover membros;
- criador da sala nao pode ser removido;
- participante pode atualizar foto de capa da sala;
- apenas criador ou administrador da conta pode apagar sala;
- administrador pode apagar qualquer chat da conta;
- administrador nao pode ler chat do qual nao participa apenas por ser admin.

## Fluxos principais

### Criar sala

1. Frontend chama `RoomsController#create`.
2. Controller autoriza via `RoomPolicy#create?`.
3. `CreateRoomService` valida usuarios da conta.
4. Sala e memberships sao criados.
5. Payload da sala volta ao frontend.

### Criar chat direto

1. Frontend chama `RoomsController#direct`.
2. `FindOrCreateDirectRoomService` calcula `direct_key`.
3. Se a sala direta ja existir, ela e retornada.
4. Se nao existir, e criada com os dois membros.

### Enviar mensagem

1. Frontend envia texto e arquivos para `MessagesController#create`.
2. Controller autoriza via `RoomPolicy#post_message?`.
3. `PostMessageService` valida conteudo e anexos.
4. Mensagem e anexos sao criados em transacao.
5. Servico dispara broadcast para membros.
6. Frontend atualiza lista e mensagens via eventos.

### Ler mensagens

1. Frontend chama `ReadsController#create`.
2. Controller autoriza via `RoomPolicy#show?`.
3. `MarkAsReadService` atualiza membership.
4. Store reduz contador de chats com mensagens novas.

### Abrir anexo

1. Payload da mensagem contem URL interna protegida.
2. Frontend busca o arquivo via Axios, com autenticacao.
3. Backend verifica se o usuario ainda participa da sala.
4. Arquivo e servido como stream.
5. Frontend renderiza um `blob:` local.

Esse desenho evita que uma URL antiga continue dando acesso depois que o membro
for removido.

## Arquivos do backend

### Controllers

| Arquivo | Responsabilidade |
| --- | --- |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/base_controller.rb` | Base dos controllers do modulo. Centraliza escopo autorizado de salas, carregamento de sala, render de payload e tratamento de erro do modulo. |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/rooms_controller.rb` | Lista, mostra, cria, atualiza e apaga salas/chats. Tambem expoe `direct` e `unread_count`. |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/messages_controller.rb` | Lista mensagens com paginacao por cursor e cria novas mensagens. |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/reads_controller.rb` | Marca sala/chat como lido no contexto de sala ativa. |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/memberships_controller.rb` | Adiciona e remove membros de salas. |
| `app/controllers/api/v1/accounts/ibsoft/internal_chat/attachments_controller.rb` | Serve anexos e previews por endpoint autorizado, sem expor URL direta do ActiveStorage. |

### Models

| Arquivo | Responsabilidade |
| --- | --- |
| `app/models/ibsoft/internal_chat/room.rb` | Modelo de sala/chat direto. Monta payload, nome de exibicao, permissoes, contagem de nao lidas e capa. |
| `app/models/ibsoft/internal_chat/membership.rb` | Participacao de usuario em sala/chat. Guarda papel e leitura. Valida usuario na conta. |
| `app/models/ibsoft/internal_chat/message.rb` | Mensagem interna. Monta payload com remetente, anexos e timestamps. |
| `app/models/ibsoft/internal_chat/attachment.rb` | Anexo de mensagem interna. Valida tipo/tamanho e monta URLs protegidas de arquivo e preview. |

### Policies

| Arquivo | Responsabilidade |
| --- | --- |
| `app/policies/ibsoft/internal_chat/room_policy.rb` | Autorizacao de listar, ver, criar, atualizar, apagar, gerenciar membros e postar mensagem. O scope lista apenas salas em que o usuario participa. |

### Services

| Arquivo | Responsabilidade |
| --- | --- |
| `app/services/ibsoft/internal_chat/create_room_service.rb` | Cria sala nomeada com criador como admin e membros iniciais. |
| `app/services/ibsoft/internal_chat/find_or_create_direct_room_service.rb` | Encontra ou cria chat direto entre dois usuarios da conta. |
| `app/services/ibsoft/internal_chat/update_room_service.rb` | Atualiza nome e/ou capa da sala respeitando regra de criador e participante. |
| `app/services/ibsoft/internal_chat/add_members_service.rb` | Adiciona membros a uma sala existente. |
| `app/services/ibsoft/internal_chat/remove_member_service.rb` | Remove membro de sala e dispara eventos. Bloqueia remocao do criador e do ultimo admin/membro. |
| `app/services/ibsoft/internal_chat/post_message_service.rb` | Cria mensagem, valida anexos, define tipo de arquivo e faz broadcast. |
| `app/services/ibsoft/internal_chat/mark_as_read_service.rb` | Atualiza ultima mensagem lida e timestamp de leitura do membership. |
| `app/services/ibsoft/internal_chat/broadcast_room_event_service.rb` | Publica eventos realtime do modulo para os membros corretos. |
| `app/services/ibsoft/internal_chat/member_lookup.rb` | Resolve usuarios validos dentro da conta para services de sala/membros. |
| `app/services/ibsoft/internal_chat/error.rb` | Erro de dominio usado pelos services do modulo. |

## Arquivos do frontend

| Arquivo | Responsabilidade |
| --- | --- |
| `app/javascript/dashboard/ibsoft/internalChat/routes.js` | Declara a rota da tela de chat interno. |
| `app/javascript/dashboard/ibsoft/internalChat/api/internalChat.js` | Cliente API do modulo. Centraliza chamadas para salas, mensagens, membros, leitura, anexos e contagem. |
| `app/javascript/dashboard/ibsoft/internalChat/store.js` | Store Vuex do modulo. Controla contador global, salas nao lidas, sala ativa e eventos realtime. |
| `app/javascript/dashboard/ibsoft/internalChat/views/InternalChat.vue` | Tela principal. Lista chats, abre sala/chat, carrega mensagens, envia mensagens/anexos, exibe composer e trata eventos locais. |
| `app/javascript/dashboard/ibsoft/internalChat/components/InternalChatComposer.vue` | Reply box interno. Orquestra editor, anexos, audio e atalhos mantendo o contrato com a tela principal. |
| `app/javascript/dashboard/ibsoft/internalChat/components/InternalChatReplyTopPanel.vue` | Painel superior do composer interno, isolado para acompanhar a composicao do `ReplyBox` do Chatwoot sem carregar modos de conversa com cliente. |
| `app/javascript/dashboard/ibsoft/internalChat/components/InternalChatReplyBottomPanel.vue` | Painel inferior do composer interno. Centraliza botoes de emoji, anexo, audio e envio usando a mesma organizacao visual do Chatwoot. |
| `app/javascript/dashboard/ibsoft/internalChat/components/MediaPreviewModal.vue` | Modal de preview de imagem/video com carregamento, zoom, rotacao, navegacao e download. |
| `app/javascript/dashboard/ibsoft/internalChat/helpers/audioNotifications.js` | Controla som de novas mensagens e sala ativa para evitar alertas indevidos. |

## Traducoes

| Arquivo | Responsabilidade |
| --- | --- |
| `app/javascript/dashboard/i18n/locale/en/ibsoftInternalChat.json` | Textos de UI em ingles para o dashboard. |
| `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftInternalChat.json` | Textos de UI em portugues do Brasil para o dashboard. |
| `config/locales/ibsoft_internal_chat.en.yml` | Textos backend em ingles, principalmente erros de dominio. |
| `config/locales/ibsoft_internal_chat.pt_BR.yml` | Textos backend em portugues do Brasil, principalmente erros de dominio. |

## Banco e schema

| Arquivo | Responsabilidade |
| --- | --- |
| `db/migrate/20260510000000_create_ibsoft_internal_chat.rb` | Cria as quatro tabelas proprias do modulo e seus indices principais. |
| `db/schema.rb` | Reflexo gerado pelo Rails apos rodar migrations. Nao deve ser editado manualmente. |

## Testes

| Arquivo | Responsabilidade |
| --- | --- |
| `spec/models/ibsoft/internal_chat/room_spec.rb` | Testa payload, permissoes, capa, seguranca de nao participantes e memberships orfas. |
| `spec/models/ibsoft/internal_chat/message_spec.rb` | Testa payload de mensagem, remetente e URLs protegidas de anexos. |
| `spec/policies/ibsoft/internal_chat/room_policy_spec.rb` | Testa regras de autorizacao do modulo. |
| `spec/services/ibsoft/internal_chat/create_room_service_spec.rb` | Testa criacao de sala e rejeicao de usuarios fora da conta. |
| `spec/services/ibsoft/internal_chat/find_or_create_direct_room_service_spec.rb` | Testa chat direto unico por par de agentes e bloqueio de chat consigo mesmo. |
| `spec/services/ibsoft/internal_chat/post_message_service_spec.rb` | Testa criacao de mensagem, broadcast e validacoes de anexos. |
| `spec/services/ibsoft/internal_chat/remove_member_service_spec.rb` | Testa remocao de membro e protecao do criador. |
| `spec/services/ibsoft/internal_chat/update_room_service_spec.rb` | Testa atualizacao de nome/capa e permissoes de edicao. |
| `spec/requests/api/v1/accounts/ibsoft/internal_chat/rooms_spec.rb` | Testa listagem, contagem de nao lidas e delecao por administrador. |
| `spec/requests/api/v1/accounts/ibsoft/internal_chat/messages_spec.rb` | Testa paginacao de mensagens e bloqueio de leitura por nao participante. |
| `spec/requests/api/v1/accounts/ibsoft/internal_chat/reads_spec.rb` | Testa marcacao de leitura apenas no contexto correto. |
| `spec/requests/api/v1/accounts/ibsoft/internal_chat/attachments_spec.rb` | Testa streaming autorizado de anexos/previews e bloqueio imediato apos remocao. |

## Pontos de acoplamento no Chatwoot original

Estes arquivos do core foram tocados para conectar o modulo. Em atualizacoes do
Chatwoot, eles sao os pontos com maior chance de conflito.

| Arquivo | Motivo do acoplamento |
| --- | --- |
| `config/routes.rb` | Registra as rotas REST do modulo dentro de `/api/v1/accounts/:account_id`. |
| `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` | Insere a rota do chat interno no dashboard. |
| `app/javascript/dashboard/store/index.js` | Registra o store `ibsoftInternalChat`. |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | Exibe o item "Chat interno" no menu e o badge de chats nao lidos. |
| `app/javascript/dashboard/helper/actionCable.js` | Recebe eventos realtime do backend e repassa para store/UI/notificacao sonora. |
| `app/javascript/dashboard/i18n/locale/en/index.js` | Importa as traducoes dashboard do modulo em ingles. |
| `app/javascript/dashboard/i18n/locale/pt_BR/index.js` | Importa as traducoes dashboard do modulo em portugues do Brasil. |
| `app/javascript/dashboard/components-next/copilot/CopilotLauncher.vue` | Permite esconder o botao flutuante do copiloto em rotas que definem `hideCopilotLauncher`. |
| `db/schema.rb` | Atualizado automaticamente pela migration do modulo. |

## Arquivo fora do escopo do modulo

`lib/chatwoot_hub.rb` aparece alterado no worktree atual, mas nao faz parte do
chat interno. Evite misturar esse tipo de ajuste com commits do modulo, pois ele
toca regra central/licenciamento e pode gerar conflitos independentes ao receber
upstream.

## Como acoplar novas funcionalidades

Ao adicionar novo recurso ao chat interno:

1. Criar primeiro o model/service/controller/componente dentro do namespace
   `Ibsoft::InternalChat` ou `dashboard/ibsoft/internalChat`.
2. Evitar alterar arquivos centrais do Chatwoot.
3. Se precisar alterar core, fazer apenas um pequeno ponto de conexao.
4. Colocar textos em arquivos de traducao.
5. Usar tokens/classes de tema existentes.
6. Adicionar teste no mesmo escopo do recurso.
7. Verificar se existe impacto em realtime, permissao, leitura e anexos.
8. Rodar teste especifico e lint.
9. Atualizar este documento quando novo arquivo ou ponto de acoplamento surgir.

## Como receber atualizacoes do Chatwoot

Fluxo recomendado:

1. Atualizar a branch alinhada ao upstream.
2. Aplicar/rebasear a branch privada do chat interno.
3. Resolver conflitos primeiro nos pontos de acoplamento listados acima.
4. Conferir se o namespace `ibsoft` nao foi afetado por refactors de base.
5. Rodar migrations se houver mudanca de schema upstream.
6. Rodar os testes do modulo:

```bash
bundle exec rspec \
  spec/models/ibsoft/internal_chat \
  spec/services/ibsoft/internal_chat \
  spec/policies/ibsoft/internal_chat \
  spec/requests/api/v1/accounts/ibsoft/internal_chat
```

7. Rodar lint dos arquivos alterados:

```bash
bundle exec rubocop \
  app/controllers/api/v1/accounts/ibsoft/internal_chat \
  app/models/ibsoft/internal_chat \
  app/services/ibsoft/internal_chat \
  app/policies/ibsoft/internal_chat \
  spec/models/ibsoft/internal_chat \
  spec/services/ibsoft/internal_chat \
  spec/policies/ibsoft/internal_chat \
  spec/requests/api/v1/accounts/ibsoft/internal_chat

pnpm exec eslint \
  app/javascript/dashboard/ibsoft/internalChat
```

## Riscos conhecidos

- `actionCable.js` e `Sidebar.vue` sao os pontos frontend mais sujeitos a
  conflito em updates do Chatwoot.
- O controller de anexos protege acesso, mas tambem faz streaming pelo app; em
  arquivos muito grandes, monitorar uso de memoria e tempo de resposta.
- Se o Chatwoot mudar autenticacao da API, revisar o carregamento de anexos via
  Axios/blob.
- Se o Chatwoot mudar estrutura de sidebar, store ou rotas, revisar os pontos
  de acoplamento antes de mexer no modulo isolado.

## Regra de manutencao

Antes de mudar o modulo, responda:

- A regra pertence mesmo ao chat interno?
- Da para implementar em arquivo proprio?
- O core precisa ser tocado ou basta um ponto de conexao?
- A permissao continua correta para membro removido?
- A tela continua coerente com o Chatwoot claro/escuro?
- Os textos estao em i18n?
- O teste cobre o comportamento novo?

Se a resposta indicar alteracao espalhada no core, redesenhe antes de
implementar.
