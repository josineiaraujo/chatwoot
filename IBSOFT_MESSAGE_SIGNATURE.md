# Assinatura de mensagens Ibsoft

## Objetivo

Adicionar o nome do agente em destaque no cabecalho das mensagens enviadas por
humanos, com configuracao geral por conta e selecao dos canais em que a regra
deve funcionar.

Formato gerado:

```text
**Nome do agente**

Conteudo da mensagem
```

O nome vem sempre do usuario que executou o envio. Nao existe texto de
assinatura livre por agente, evitando divergencias e configuracoes obsoletas.

## Decisoes arquiteturais

- O modulo e integralmente privado e usa o namespace
  `Ibsoft::MessageSignature`.
- Nao reutiliza `User#message_signature`, o delimitador `--` nem a chave de UI
  por canal da assinatura nativa.
- Nao cria tabela, migration, job, fila, cache ou variavel de ambiente.
- A configuracao fica na chave `ibsoft_message_signature` do JSONB
  `accounts.settings`, que ja acompanha a conta carregada pelo
  `Messages::MessageBuilder`.
- A atualizacao usa `Account#with_lock` e mescla apenas a chave privada, para
  preservar configuracoes nativas e de outros modulos em atualizacoes
  concorrentes.
- A assinatura e aplicada de forma sincrona antes da persistencia da mensagem.
  O custo e apenas manipulacao de string e leitura de dados ja carregados.
- Requisicoes autenticadas pelo token da API publica sao identificadas em um
  contexto isolado por requisicao e preservam o conteudo recebido sem
  assinatura.
- O modulo e seguro para multiplas instancias Rails e auto scaling porque a
  fonte de verdade e o PostgreSQL compartilhado e nao existe estado local.

## Configuracao persistida

Exemplo da chave dentro de `accounts.settings`:

```json
{
  "ibsoft_message_signature": {
    "enabled": true,
    "inbox_ids": [1, 4]
  }
}
```

Os IDs sao validados contra os canais da propria conta, normalizados, removidos
de duplicidade e ordenados. Ativar a funcao exige pelo menos um canal.

## Backend

### Servicos privados

- `app/services/ibsoft/message_signature/configuration.rb`: leitura tipada e
  payload da configuracao.
- `configuration_updater.rb`: validacao, lock da conta e persistencia por
  merge.
- `permission.rb`: autorizacao administrativa e permissao privada
  `ibsoft_chathub_settings_manage`.
- `policy.rb`: decide se a mensagem pode receber assinatura.
- `header_formatter.rb`: normaliza e escapa o nome, evita duplicidade e respeita
  o limite de tamanho do model `Message`.
- `native_footer_sanitizer.rb`: remove somente o rodape nativo exato que possa
  existir em um rascunho antigo.
- `message_builder_extension.rb`: ponto privado que compoe sanitizacao,
  politica e formatacao.
- `request_context.rb`: estado isolado da requisicao atual, implementado com
  `ActiveSupport::CurrentAttributes`.
- `api_request_context.rb`: identifica a autenticacao por
  `api_access_token` sem alterar controllers nativos.

### API privada

- `GET /api/v1/accounts/:account_id/ibsoft/message_signature/setting`
- `PATCH /api/v1/accounts/:account_id/ibsoft/message_signature/setting`

Payload de escrita:

```json
{
  "enabled": true,
  "inbox_ids": [1, 4]
}
```

Controllers:

- `app/controllers/api/v1/accounts/ibsoft/message_signature/base_controller.rb`
- `app/controllers/api/v1/accounts/ibsoft/message_signature/settings_controller.rb`

## Regras de aplicacao

A assinatura e adicionada somente quando todas as condicoes forem satisfeitas:

- configuracao ativa na conta;
- canal atual selecionado;
- envio publico e de saida;
- autor humano do tipo `User`;
- parametros originados de uma requisicao interativa do dashboard;
- requisicao autenticada pela sessao do dashboard, nao pelo token da API
  publica;
- conteudo textual nao vazio;
- mensagem sem template Meta, campanha, regra de automacao ou HTML de e-mail
  customizado.

O modulo nao altera:

- mensagens recebidas;
- mensagens enviadas pela API publica com `api_access_token`;
- notas privadas;
- mensagens de `AgentBot`, sistema ou automacoes backend;
- templates Meta;
- disparos em massa;
- anexos sem legenda;
- chat interno;
- mensagens em canais nao selecionados.

Se o conteudo ja comecar com o mesmo cabecalho, ele nao e duplicado. Se a soma
do cabecalho ultrapassar o limite do model, o conteudo original e preservado
para nao transformar uma mensagem valida em erro de envio.

## Frontend

Arquivos privados:

- `app/javascript/dashboard/ibsoft/messageSignature/api.js`
- `app/javascript/dashboard/ibsoft/messageSignature/nativeSignature.js`
- `app/javascript/dashboard/ibsoft/messageSignature/components/SettingsPanel.vue`
- `app/javascript/dashboard/ibsoft/messageSignature/specs/`

A tela fica em `Configuracoes de canais e departamentos > Assinatura de
mensagens`, com:

- ativacao geral;
- pesquisa e selecao dos canais;
- contagem de canais selecionados;
- preview usando o nome do usuario atual;
- estados de loading, vazio, erro e salvamento;
- tokens de tema compativeis com claro e escuro.

Os textos ficam nos arquivos `ibsoftTheme.json` de `pt_BR` e `en`.

## Neutralizacao da assinatura nativa

O codigo e os dados nativos sao preservados para facilitar rollback e updates.
Somente o funcionamento visual e a composicao de novos rodapes sao
neutralizados:

- `app/javascript/dashboard/store/modules/auth.js` delega o getter nativo ao
  helper privado `resolveNativeMessageSignature`, que retorna vazio.
- `app/javascript/dashboard/ibsoft/theme/_dark-overrides.scss` oculta a secao
  nativa do perfil e o botao nativo do compositor.
- `NativeFooterSanitizer` remove no backend um rodape antigo apenas quando ele
  corresponde exatamente a `User#message_signature`.

Nao foram alterados `Profile/Index.vue`, `MessageSignature.vue`,
`ReplyBottomPanel.vue`, `editorHelper.js`, o model `User` ou a coluna nativa.

## Pontos de acoplamento no Chatwoot

- `config/routes.rb`: registra dois endpoints privados.
- `config/initializers/ibsoft_message_signature.rb`: prepend idempotente da
  extensao privada em `Messages::MessageBuilder` e registro do contexto no
  `Api::BaseController`.
- `app/javascript/dashboard/store/modules/auth.js`: uma delegacao para impedir
  a composicao do rodape nativo.
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  registra a tela privada no menu de configuracoes.
- arquivos `ibsoftTheme.json`: traducoes da tela.

Toda regra de negocio permanece dentro do modulo privado.

## Testes

Backend:

```bash
bundle exec rspec spec/services/ibsoft/message_signature \
  spec/requests/api/v1/accounts/ibsoft/message_signature
bundle exec rubocop app/services/ibsoft/message_signature \
  app/controllers/api/v1/accounts/ibsoft/message_signature \
  config/initializers/ibsoft_message_signature.rb \
  spec/services/ibsoft/message_signature \
  spec/requests/api/v1/accounts/ibsoft/message_signature/settings_spec.rb
```

Frontend:

```bash
pnpm exec vitest run \
  app/javascript/dashboard/ibsoft/messageSignature/specs \
  app/javascript/dashboard/ibsoft/chathubSettings/specs/settingsSections.spec.js \
  app/javascript/dashboard/store/modules/specs/auth/getters.spec.js
pnpm exec eslint app/javascript/dashboard/ibsoft/messageSignature
```

Validacao manual:

1. Ativar a assinatura e selecionar um canal.
2. Enviar mensagem publica nesse canal e conferir o nome em destaque no topo.
3. Enviar nota privada e confirmar que nao foi assinada.
4. Enviar template WhatsApp e confirmar que nao foi alterado.
5. Enviar mensagem por canal nao selecionado e confirmar que ficou intacta.
6. Desativar a configuracao e confirmar que novos envios nao recebem cabecalho.
7. Enviar o mesmo texto com `api_access_token` e confirmar que ele foi
   preservado sem assinatura.
8. Validar a tela nos temas claro e escuro.

## Atualizacao do upstream

Ao sincronizar com o Chatwoot oficial:

1. Verificar se `Messages::MessageBuilder#message_params` continua sendo o
   ponto que antecede a persistencia.
2. Confirmar que o initializer ainda prepende a extensao uma unica vez.
3. Confirmar que `Api::BaseController#authenticate_by_access_token?` continua
   identificando as chamadas feitas com `api_access_token`.
4. Revisar o contrato do getter `getMessageSignature`.
5. Conferir se os seletores do perfil e do botao nativo ainda correspondem ao
   markup atual.
6. Rodar as baterias backend e frontend acima.
7. Validar um envio WhatsApp real em homologacao.

Se o upstream criar um hook oficial para transformar conteudo antes da
persistencia, migrar a extensao para esse hook e remover o prepend.
