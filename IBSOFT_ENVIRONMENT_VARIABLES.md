# Variaveis de ambiente e configuracao Ibsoft

Este documento lista as variaveis que precisam ser consideradas ao instalar,
atualizar ou publicar a imagem ChatHub/Ibsoft em producao.

Ele separa variaveis nativas do Chatwoot de variaveis criadas pelos modulos
Ibsoft. Antes de subir uma nova imagem, confirme se o `.env` usado por `rails`
e `sidekiq` contem os valores corretos.

## Resumo rapido para producao

Configuracao recomendada para operacao ativa:

```env
INSTALLATION_NAME=ChatHub
DEFAULT_LOCALE=pt_BR

IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=true
IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true
IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT=50
IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS=300
IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS=900

# Necessarias somente para importar feriados pela Invertexto
IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN=configure-via-secret-manager
```

Configuracao recomendada para primeira subida segura:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=true
IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false
```

Com `REAL_ASSIGNMENT_ENABLED=false`, o watchdog roda, gera auditoria e permite
validar as politicas, mas nao altera conversas reais. Depois da validacao,
troque para `true`.

## Onde configurar

No Docker Compose de producao, coloque as variaveis no arquivo `.env` usado
pelos servicos:

- `rails`;
- `sidekiq`.

O `sidekiq` precisa receber as variaveis porque o watchdog de distribuicao roda
em background. Se apenas o `rails` receber as variaveis, a interface pode abrir,
mas o job automatico nao tera a configuracao correta.

Depois de alterar o `.env`, recrie os containers que leem ambiente:

```bash
docker compose up -d --force-recreate rails sidekiq
```

Se o `vite` estiver rodando em desenvolvimento local e a mudanca afetar o
frontend, recrie tambem:

```bash
docker compose up -d --force-recreate rails sidekiq vite
```

Em producao com imagem ja compilada, normalmente nao existe container `vite`.

## Variaveis nativas do Chatwoot

### INSTALLATION_NAME

Exemplo:

```env
INSTALLATION_NAME=ChatHub
```

Origem:

- Nativa do Chatwoot.

Motivo:

- Define o nome da instalacao exibido pelo dashboard e por helpers de branding.
- Nosso patch de preview de remetente usa o helper nativo `useBranding`, entao
  textos de exemplo que seriam `Chatwoot` passam a usar `INSTALLATION_NAME`.

Cuidados:

- O Chatwoot tambem persiste essa configuracao em `installation_configs`.
- Em instalacoes existentes, o valor salvo no banco pode prevalecer sobre o
  `.env`.
- Apenas colocar no `.env` pode nao alterar o valor efetivo se ja existir uma
  linha `INSTALLATION_NAME` no banco.

Como verificar o valor efetivo:

```bash
docker compose exec rails bundle exec rails runner "puts GlobalConfigService.load('INSTALLATION_NAME', 'Chatwoot')"
```

Como ajustar em uma instalacao existente:

```bash
docker compose exec rails bundle exec rails runner "config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_NAME'); config.value = 'ChatHub'; config.locked = false if config.respond_to?(:locked=); config.save!; GlobalConfig.clear_cache"
```

### DEFAULT_LOCALE

Exemplo:

```env
DEFAULT_LOCALE=pt_BR
```

Origem:

- Nativa do Chatwoot.

Motivo:

- Define o idioma padrao para paginas nao autenticadas e para novas contas.
- Ajuda a manter o ChatHub em portugues do Brasil por padrao.

Cuidados:

- Usuarios existentes podem manter preferencias individuais de idioma.
- Essa variavel nao substitui traducoes ausentes. Ela apenas escolhe o locale
  padrao.

### ACTIVE_RECORD_ENCRYPTION_*

Exemplo:

```env
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

Origem:

- Nativas do Chatwoot/Rails.

Motivo:

- Protegem campos sensiveis no banco.
- O modulo Ibsoft de API de templates usa essa criptografia para a chave PIX
  padrao da instancia e para o snapshot transitorio necessario ao worker.

Cuidados:

- As tres variaveis devem estar presentes em `rails` e `sidekiq`.
- Em producao, o modulo recusa gravar uma chave PIX se a criptografia nao
  estiver configurada.
- Gere os valores pelo procedimento oficial do Chatwoot/Rails e armazene-os em
  cofre de segredos. Nao reutilize valores de desenvolvimento.
- Perder ou trocar as chaves sem migracao impede a leitura dos segredos ja
  gravados.

### WHATSAPP_CLOUD_BASE_URL e WHATSAPP_API_VERSION

Exemplo:

```env
WHATSAPP_CLOUD_BASE_URL=https://graph.facebook.com
WHATSAPP_API_VERSION=v22.0
```

Origem:

- Nativas do Chatwoot.

Motivo:

- Definem a origem e a versao da Graph API usadas pelo WhatsApp Business Cloud.
- O modulo Ibsoft de mensagens externas reutiliza esses valores para enviar
  diretamente pela Meta.

Cuidados:

- Prefira a versao homologada pela versao atual do Chatwoot.
- `WHATSAPP_API_VERSION` tambem pode ser controlada por
  `installation_configs` via `GlobalConfigService`.
- Nao altere a versao apenas no container Rails; workers Sidekiq precisam
  receber a mesma configuracao.

### WHATSAPP_APP_ID

Exemplo:

```env
WHATSAPP_APP_ID=123456789012345
```

Origem:

- Nativa do Chatwoot para o WhatsApp Embedded Signup.

Motivo:

- Identifica o aplicativo Meta usado pela integracao WhatsApp Embedded.
- O modulo Ibsoft de modelos usa esse identificador para abrir sessoes de
  upload resumivel de imagens, videos e documentos usados como amostra.

Cuidados:

- A listagem e a edicao de modelos sem midia continuam funcionando sem essa
  variavel.
- O upload de amostras de midia exige o ID do mesmo aplicativo associado ao
  token do canal.
- A tela administrativa do WhatsApp Embedded persiste o valor em
  `installation_configs`; o modulo o reutiliza por `GlobalConfigService`.
- Nao duplique o valor em `provider_config` do canal.

### ACTIVE_STORAGE_SERVICE e storage compartilhado

Exemplo local:

```env
ACTIVE_STORAGE_SERVICE=local
```

Exemplo recomendado para producao com autoscaling:

```env
ACTIVE_STORAGE_SERVICE=amazon
S3_BUCKET_NAME=chathub-production
AWS_REGION=sa-east-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
```

Origem:

- Nativas do Chatwoot/Active Storage.

Motivo:

- Armazenam anexos do Chatwoot e dos modulos privados, inclusive chat interno.
- Object storage permite que varias replicas Rails e Sidekiq acessem os mesmos
  arquivos sem depender do disco efemero de uma instancia.

Cuidados:

- `local` exige que Rails e Sidekiq compartilhem e preservem `/app/storage`.
- `local` nao deve ser usado entre replicas em hosts diferentes sem filesystem
  compartilhado.
- Em S3, o bucket deve ser privado e permitir CORS `GET`/`HEAD` para os dominios
  do ChatHub. O chat interno autoriza o usuario e depois entrega URL assinada de
  um minuto para o navegador.
- Rails e Sidekiq devem receber os mesmos valores de storage.
- A fila `default` do Sidekiq precisa estar ativa para analise e previews do
  Active Storage.
- Alterar `ACTIVE_STORAGE_SERVICE` nao copia objetos antigos. Planeje a migracao
  de `/app/storage` para o bucket antes de retirar o volume local.
- A configuracao `amazon` atual em `config/storage.yml` recebe explicitamente
  `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`. Usar IAM Role sem chaves exige
  primeiro adaptar essa configuracao e validar o SDK; nao assuma esse suporte
  no estado atual do repositorio.

Exemplo minimo de CORS do bucket, ajustando os dominios reais:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": ["https://ibsoftcloud.com.br:3443"],
    "ExposeHeaders": ["Content-Length", "Content-Type", "ETag"]
  }
]
```

O chat interno nao adiciona variavel Ibsoft para storage: ele respeita o service
nativo selecionado por `ACTIVE_STORAGE_SERVICE`.

## Variaveis Ibsoft

As variaveis abaixo nao fazem parte do Chatwoot oficial. Elas controlam modulos
privados Ibsoft.

### IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN

Exemplo:

```env
IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN=configure-via-secret-manager
```

Origem:

- Ibsoft.

Motivo:

- Autentica o backend Rails na API Invertexto para visualizar e importar
  feriados nacionais e estaduais.
- O token nao e salvo no banco e nao e enviado ao navegador.

Cuidados:

- E obrigatorio somente para preview e importacao pela Invertexto.
- Cadastro manual, vinculos e deteccao de feriados salvos funcionam sem ele.
- Configure como segredo e nunca registre o valor em Git ou logs.
- Atualmente apenas o container Rails realiza essa consulta.

### IBSOFT_META_TEMPLATES_TIMEOUT_SECONDS

Exemplo opcional:

```env
IBSOFT_META_TEMPLATES_TIMEOUT_SECONDS=20
```

Origem:

- Ibsoft.

Motivo:

- Define o timeout das operacoes de catalogo, criacao, edicao e exclusao de
  modelos na Graph API.

Default:

- `20` segundos.
- Valores sao limitados automaticamente entre 5 e 60 segundos.

Cuidados:

- Nao e obrigatoria.
- Como as operacoes administrativas rodam no container Rails, a variavel
  precisa estar disponivel nesse servico.

### IBSOFT_META_TEMPLATES_UPLOAD_TIMEOUT_SECONDS

Exemplo opcional:

```env
IBSOFT_META_TEMPLATES_UPLOAD_TIMEOUT_SECONDS=60
```

Origem:

- Ibsoft.

Motivo:

- Define o timeout da transferencia em streaming de amostras de imagem, video
  e documento para a Meta.

Default:

- `60` segundos.
- Valores sao limitados automaticamente entre 10 e 180 segundos.

Cuidados:

- Nao e obrigatoria.
- Aumente apenas quando a rede ou o tamanho permitido das amostras justificar.
- O upload acontece no Rails e nao depende do Sidekiq.

### IBSOFT_EXTERNAL_MESSAGING_META_TIMEOUT_SECONDS

Exemplo opcional:

```env
IBSOFT_EXTERNAL_MESSAGING_META_TIMEOUT_SECONDS=20
```

Origem:

- Ibsoft.

Motivo:

- Define o timeout HTTP do worker que envia templates externos diretamente
  para a Meta.

Default:

- `20` segundos.
- Valores sao limitados automaticamente entre 5 e 60 segundos.

Cuidados:

- Nao e obrigatoria.
- Um timeout deixa a entrega como `uncertain` e nao causa retry automatico,
  porque a Meta pode ter aceitado a mensagem antes da interrupcao da resposta.
- Configure o mesmo valor em todos os containers Sidekiq.

### IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED

Exemplo:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED=true
```

Origem:

- Ibsoft.

Motivo:

- Liga ou desliga o watchdog automatico de distribuicao.
- Quando `false`, o cron/job pode existir, mas retorna sem processar filas.

Valores:

- `true`: o watchdog automatico roda.
- `false`: o watchdog automatico fica inerte.

Recomendacao:

- Em producao, usar `true` quando quiser que a distribuicao automatica rode.
- Para homologacao inicial, pode usar `true` junto com
  `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=false`.

### IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED

Exemplo:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true
```

Origem:

- Ibsoft.

Motivo:

- Controla se o modulo pode alterar conversas de verdade.
- Protege producao contra atribuicoes reais antes da validacao operacional.

Valores:

- `true`: o modulo pode atribuir, redistribuir, transferir para fallback e
  executar acoes reais configuradas.
- `false`: o modulo simula, registra logs de auditoria e nao altera
  `assignee_id` nem roteamento real.

Recomendacao:

- Primeira subida: `false`.
- Depois de validar logs, politicas e dashboard: `true`.

### IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT

Exemplo:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_JOB_LIMIT=50
```

Origem:

- Ibsoft.

Motivo:

- Define o teto tecnico de conversas candidatas avaliadas por rodada do
  watchdog.
- Evita consultas e processamentos grandes demais em uma unica execucao.

Cuidados:

- Nao e regra operacional de distribuicao.
- Nao substitui limites configurados nas politicas de atendimento.
- O limite operacional por canal/departamento fica nas politicas do dashboard,
  como limite por rodada, limite por janela ou limite de conversas abertas.

Default:

- Se ausente, usa o limite padrao do `CandidateFinder`.

Recomendacao:

- Manter `50` inicialmente.
- Aumentar somente depois de observar carga de banco, Redis e Sidekiq.

### IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS

Exemplo:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_WATCHDOG_LOCK_TTL_SECONDS=300
```

Origem:

- Ibsoft.

Motivo:

- Define o tempo de vida do lock Redis usado para evitar rodadas concorrentes
  do watchdog no mesmo escopo.

Default:

- `300` segundos.

Cuidados:

- Valor muito baixo pode permitir sobreposicao se uma rodada demorar mais que o
  TTL.
- Valor muito alto pode atrasar a proxima rodada se um processo morrer no meio
  da execucao.

Recomendacao:

- Manter `300` em producao, salvo se os logs mostrarem rodadas longas.

### IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS

Exemplo:

```env
IBSOFT_CONVERSATION_DISTRIBUTION_EVENT_DEDUPE_WINDOW_SECONDS=900
```

Origem:

- Ibsoft.

Motivo:

- Define a janela de deduplicacao de eventos repetidos de auditoria.
- Evita crescimento artificial da tabela de logs quando a mesma conversa e
  reavaliada em varias rodadas sem mudanca de estado.

Default:

- `900` segundos, ou 15 minutos.

Cuidados:

- Valor muito baixo aumenta volume de logs repetidos.
- Valor muito alto pode esconder repeticoes relevantes na auditoria.

Recomendacao:

- Manter `900` inicialmente.

## O que nao e variavel de ambiente

As configuracoes abaixo sao salvas no banco e gerenciadas pelas telas Ibsoft.
Nao devem ser configuradas via `.env`:

- politicas de distribuicao;
- vinculo de politica ao canal;
- vinculo de politica ao departamento;
- horario de funcionamento por politica;
- fallback por indisponibilidade ou fora de horario;
- mensagem automatica ao cliente;
- janela de estabilizacao pos-login;
- percentual minimo do modal pos-login;
- perfis e permissoes;
- configuracoes do chat interno.
- defaults PIX das instancias da API de templates Meta.
- calendarios e datas de feriados;
- vinculos entre calendarios e departamentos;
- politicas extra expediente, mensagens e comando de saida.

## Comandos de verificacao

Ver variaveis dentro do container `rails`:

```bash
docker compose exec rails printenv INSTALLATION_NAME
docker compose exec rails printenv IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED
docker compose exec rails printenv IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED
docker compose exec rails /bin/sh -lc 'test -n "$IBSOFT_INVERTEXTO_HOLIDAYS_TOKEN" && echo configurado || echo ausente'
```

Ver variaveis dentro do container `sidekiq`:

```bash
docker compose exec sidekiq printenv IBSOFT_CONVERSATION_DISTRIBUTION_JOB_ENABLED
docker compose exec sidekiq printenv IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED
```

Ver o valor efetivo de branding usado pelo Chatwoot:

```bash
docker compose exec rails bundle exec rails runner "puts GlobalConfigService.load('INSTALLATION_NAME', 'Chatwoot')"
```

Confirmar se o Sidekiq esta rodando:

```bash
docker compose ps sidekiq
```

## Checklist de producao

Antes de publicar:

1. Adicionar as variaveis no `.env` de producao.
2. Garantir que `rails` e `sidekiq` recebem o mesmo `.env`.
3. Rodar migrations.
4. Recriar `rails` e `sidekiq`.
5. Conferir `INSTALLATION_NAME` efetivo via `GlobalConfigService`.
6. Iniciar com atribuicao real desligada se ainda estiver homologando.
7. Validar logs de auditoria e dashboard de supervisao.
8. Ligar `IBSOFT_CONVERSATION_DISTRIBUTION_REAL_ASSIGNMENT_ENABLED=true`.
