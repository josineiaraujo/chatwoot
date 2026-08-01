# Politica de entrada do Instagram Ibsoft

## Objetivo

Controlar quais interacoes recebidas pelo webhook do Instagram podem iniciar
uma nova conversa, sem impedir que essas mesmas interacoes sejam adicionadas a
uma conversa que ja esteja em andamento com o contato.

O modulo e exclusivo do Instagram. Eventos do Facebook Messenger, WhatsApp,
widget, e-mail e demais canais nao passam por esta politica.

## Comportamento

As tres categorias configuraveis por canal sao:

- respostas e mencoes em Stories;
- compartilhamento de Reels e Stories;
- compartilhamento de publicacoes.

Uma mensagem direta comum sempre segue o fluxo nativo do Chatwoot.

Os formatos classificados no envelope `entry[].messaging[]` sao:

- `message.reply_to.story`: resposta a Story;
- attachment `story_mention`: mencao em Story;
- attachments `ig_reel` e `reel`: compartilhamento de Reel;
- attachment `ig_story`: compartilhamento de Story reconhecido pelo Chatwoot;
- attachments `ig_post` e `share`: compartilhamento de publicacao ou midia.

O tipo `share` pertence a publicacoes porque a Meta informa que, nesse formato,
o webhook pode entregar somente a URL da midia ou publicacao compartilhada.
Tipos de arquivo comuns como `image`, `video`, `audio` e `file` nao sao
classificados como interacoes e continuam no fluxo nativo.

Comentarios publicos nao fazem parte deste modulo. O Chatwoot atual nao cria
conversas a partir deles, e a customizacao nao altera, bloqueia, assina ou
processa os webhooks `comments` e `live_comments`.

Para uma interacao configuravel:

1. Se for um eco de saida, o evento segue normalmente.
2. Se existir conversa `open`, `pending` ou `snoozed` para o mesmo contato e
   canal, a interacao segue normalmente.
3. Se existir apenas conversa `resolved`, ela nao e considerada ativa.
4. Sem conversa ativa, a opcao do canal decide se o evento pode criar contato,
   conversa e mensagem.

As opcoes nascem habilitadas. Assim, aplicar a migration sem abrir ou salvar a
tela preserva integralmente o comportamento anterior.

## Persistencia

Migration:

- `db/migrate/20260723120000_create_ibsoft_instagram_inbound_policies.rb`

Tabela:

- `ibsoft_instagram_inbound_policies`

Campos funcionais:

- `account_id`;
- `inbox_id`;
- `create_from_story_interactions`;
- `create_from_shared_reels_and_stories`;
- `create_from_shared_posts`.

Existe apenas um registro por conta e canal. A consulta da tela nao cria
registro; a politica so e persistida quando o administrador salva uma
alteracao.

O modulo nao possui tabela de eventos, payload, auditoria, contador ou
historico. Eventos bloqueados nao sao armazenados e nao geram log por evento.

## Backend

Model:

- `app/models/ibsoft/instagram_inbound/policy.rb`

Services:

- `event_classifier.rb`: classifica somente estruturas conhecidas do webhook;
- `conversation_gate.rb`: aplica a regra do canal e verifica conversa ativa;
- `instagram_events_job_extension.rb`: aplica a politica no metodo privado
  `message`, sempre antes de buscar perfil ou criar dados.

Initializer:

- `config/initializers/ibsoft_instagram_inbound.rb`

O initializer usa `prepend` idempotente em
`Webhooks::InstagramEventsJob`. Nenhum arquivo do processamento nativo de
Instagram foi editado.

Em erro inesperado, o gate falha de forma aberta: informa apenas modulo,
`account_id` e `inbox_id` ao error reporter e permite o fluxo nativo. O payload
e o conteudo da mensagem nao sao enviados pelo modulo ao log ou reporter.

Referencias de payload:

- Meta Instagram API, Messaging webhook:
  `https://www.postman.com/meta/instagram/request/23987686-95cce6f6-b811-41dc-b560-d43741c5002a`;
- factories e specs nativos em
  `spec/factories/instagram/instagram_message_create_event.rb` e
  `spec/jobs/webhooks/instagram_events_job_spec.rb`.

## API

Endpoints administrativos:

- `GET /api/v1/accounts/:account_id/ibsoft/instagram_inbound/inbox_policies/:inbox_id`
- `PATCH /api/v1/accounts/:account_id/ibsoft/instagram_inbound/inbox_policies/:inbox_id`

Os controllers ficam em:

- `app/controllers/api/v1/accounts/ibsoft/instagram_inbound/`

Somente administradores da conta podem consultar ou alterar. O canal precisa
pertencer a conta atual e responder positivamente a `Inbox#instagram?`, o que
abrange Instagram direto e pagina do Facebook conectada ao Instagram.

## Frontend

Arquivos privados:

- `app/javascript/dashboard/ibsoft/instagramInbound/api.js`;
- `app/javascript/dashboard/ibsoft/instagramInbound/components/SettingsPanel.vue`;
- `app/javascript/dashboard/ibsoft/instagramInbound/specs/`.

A tela e exibida como a aba `Interacoes do Instagram` dentro da configuracao
nativa do canal. Ela possui loading, erro recuperavel, salvamento e tres
switches. Todos os estilos usam componentes e tokens de tema do Chatwoot.

Traducoes proprias:

- `app/javascript/dashboard/i18n/locale/en/ibsoftInstagramInbound.json`;
- `app/javascript/dashboard/i18n/locale/pt_BR/ibsoftInstagramInbound.json`.

Nenhum campo persistente sem efeito foi criado para comentarios.

## Pontos de acoplamento

Arquivos nativos tocados:

- `config/routes.rb`: registra a API privada;
- `app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`:
  registra uma aba condicional e monta o componente privado;
- `app/javascript/dashboard/i18n/locale/en/index.js`: registra a traducao;
- `app/javascript/dashboard/i18n/locale/pt_BR/index.js`: registra a traducao;
- `db/schema.rb`: atualizado pela migration.

Toda classificacao, decisao, persistencia, interface e cobertura ficam no
namespace Ibsoft.

## Escala e desempenho

- Mensagens diretas comuns nao consultam a tabela da politica.
- Somente eventos das tres categorias executam a verificacao.
- A busca de conversa ativa usa `exists?` e nao instancia conversa.
- Eventos bloqueados param antes da consulta de perfil na Meta.
- Nao existem worker adicional, Redis, estado local ou escrita por evento.
- A fonte de verdade e o PostgreSQL compartilhado, compativel com varias
  instancias Rails e auto scaling.

## Testes

Backend:

```bash
bundle exec rspec \
  spec/models/ibsoft/instagram_inbound/policy_spec.rb \
  spec/services/ibsoft/instagram_inbound/event_classifier_spec.rb \
  spec/services/ibsoft/instagram_inbound/conversation_gate_spec.rb \
  spec/jobs/ibsoft/instagram_inbound/instagram_events_job_extension_spec.rb \
  spec/requests/api/v1/accounts/ibsoft/instagram_inbound/inbox_policies_spec.rb
```

Frontend:

```bash
pnpm test \
  app/javascript/dashboard/ibsoft/instagramInbound/specs/SettingsPanel.spec.js
```

Validacao manual:

1. Abrir um canal Instagram e acessar `Interacoes do Instagram`.
2. Desativar uma categoria e salvar.
3. Enviar a interacao sem conversa ativa e confirmar que nada foi criado.
4. Iniciar uma DM comum e confirmar que a conversa foi criada.
5. Com a conversa aberta, repetir a interacao bloqueada e confirmar que a
   mensagem entrou na conversa existente.
6. Repetir nos temas claro e escuro.

## Atualizacao do upstream

Antes de sincronizar:

1. Conferir se `Webhooks::InstagramEventsJob` ainda possui o metodo privado
   `message(messaging, channel)`.
2. Conferir novos formatos de attachment da Meta e atualizar apenas
   `EventClassifier`.
3. Verificar se `Inbox#instagram?` continua abrangendo Instagram direto e
   Facebook Page com `instagram_id`.
4. Resolver eventual conflito em `Settings.vue` preservando apenas o import,
   a aba condicional e a montagem do componente.
5. Rodar a suite do modulo e os specs nativos do job/builder do Instagram.

Se o Chatwoot passar a oferecer politica equivalente, comparar os contratos,
migrar os tres valores e remover o ponto privado em vez de manter duas regras
concorrentes.
