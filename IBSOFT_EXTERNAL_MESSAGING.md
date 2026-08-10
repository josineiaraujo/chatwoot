# API de cobranca

## Objetivo

Receber solicitacoes autenticadas de ERPs e enviar templates diretamente pela
API do WhatsApp Business Cloud, sem criar contato, conversa ou mensagem no
Chatwoot.

O modulo e separado do disparo em massa operado pelo dashboard. O ERP e o
produtor das solicitacoes e o ChatHub valida, persiste e processa cada envio
assincronamente.

## Decisoes funcionais

- somente canais `Channel::Whatsapp` com provider `whatsapp_cloud` podem ser
  vinculados;
- uma conta pode criar varias instancias;
- cada instancia possui um tipo imutavel e pertence a exatamente uma conta e
  um canal;
- os tipos atuais sao `sgp_generic`, exibido como **SGP Generico**, e `ixc`,
  exibido como **IXC**;
- cada contrato possui autenticacao propria, mas a credencial sempre identifica
  instancia, conta e canal;
- segredos em texto puro sao exibidos somente na criacao ou rotacao;
- abrir a gestao de credenciais e uma operacao somente de leitura e nunca
  rotaciona o segredo ativo; a rotacao exige uma acao administrativa explicita;
- o envio vai direto para a Meta;
- o modulo nao cria, abre, fecha, atribui ou modifica conversas;
- templates do tipo `order` exigem `order.reference_id`;
- uma instancia permite, por padrao, reenviar cobrancas para a mesma ordem;
- a mesma referencia sempre identifica uma unica ordem e um unico destinatario
  dentro da instancia, mas cada reenvio possui entrega e historico proprios;
- ordens pagas, concluidas ou canceladas nao aceitam novos envios;
- nao existe retry automatico depois de uma tentativa com resultado ambiguo;
- o SGP usa `msg`, `to` e `token`; o IXC preserva exatamente o envelope nativo
  `user`, `pw`, `dest` e `text`;
- atualizacoes de pedido usam um contrato compartilhado por familia em
  `/chathub-sender/<familia>/pedido/`, independentemente do contrato de criacao;
- novos tipos devem ser registrados em `InstanceTypeRegistry`, com parser e
  contrato proprios, sem condicionais no controller.

## Contrato publico SGP Generico

O contrato SGP Generico e exatamente:

```http
GET /chathub-sender/sgp/generico/
```

No caminho publico, `sgp` identifica a familia da integracao e `generico`
identifica o contrato da API. Um futuro contrato padrao devera ser registrado
como outro tipo de instancia e usar `/chathub-sender/sgp/padrao/`, com parser e
contrato proprios. O token somente e aceito na rota correspondente ao tipo da
instancia que o emitiu para criar uma mensagem. A rota de pedido aceita tokens
de qualquer tipo registrado na familia `sgp`, desde que a ordem pertenca a
mesma conta e ao mesmo canal da instancia.

Parametros obrigatorios:

- `msg`: template e variaveis no formato
  `[campo]=valor||[outro_campo]=valor`;
- `to`: telefone do destinatario com DDI, DDD e somente numeros;
- `token`: token exclusivo gerado ao criar o endpoint.

Exemplo completo:

```bash
curl --get 'https://josinei.ibsoftcloud.com.br/chathub-sender/sgp/generico/' \
  --data-urlencode 'msg=[template_name]=lembrete_fatura_pdf_pix||[template_type]=order||[header_type]=document||[header_link]=https://sistema.asnetwork.net.br/boleto/9388-0CFLCN1OMD.pdf||[header_append_pdf]=false||[body.nome_cliente]=Jose Augusto Silva||[body.vencimento_fatura]=10/08/2027||[order.reference_id]=9388||[order.total]=64,99||[order.item_name]=Fatura de internet||[order.payment.pix.code]=PIX_COPIA_E_COLA_COMPLETO||[order.payment.pix.merchant_name]=IBSoft Cloud||[order.payment.pix.key]=12345678000199||[order.payment.pix.key_type]=CNPJ||[order.payment.boleto.digitable_line]=00190000090350182490218767625173516510000006499' \
  --data-urlencode 'to=5575982479788' \
  --data-urlencode 'token=TOKEN_DO_ENDPOINT'
```

Nao existem contratos publicos alternativos em JSON, POST, Bearer,
`external_id` ou `Idempotency-Key`. Conta e canal nao sao recebidos: sao
obtidos exclusivamente pelo token.

Como o contrato exige dados na query string, a aplicacao filtra `msg`, `to` e
`token` dos logs Rails e devolve respostas com `Cache-Control: no-store`. Em
producao, o proxy e o balanceador tambem devem omitir a query string dos access
logs dessa rota. A chamada deve usar sempre HTTPS.

O parametro `msg` tambem tolera o prefixo redundante `msg=` ou um comando
copiado cujo conteudo esteja em `--data-raw`. Isso e apenas normalizacao do
mesmo parametro, nao outro contrato de API.

## Contrato publico IXC

O tipo `ixc` preserva o contrato utilizado nativamente pelo ERP:

```http
GET|POST /chathub-sender/ixc/
```

Campos obrigatorios do envelope:

| Campo | Limite | Regra |
| --- | --- | --- |
| `user` | 256 bytes | usuario exclusivo e estavel da instancia |
| `pw` | 1.024 bytes | senha exibida somente na criacao ou rotacao |
| `dest` | 64 bytes na entrada | telefone normalizado para 10 a 15 digitos |
| `text` | 64 KiB | mesmo formato semantico `[campo]=valor||...` do SGP |

Exemplo:

```bash
curl --get 'https://josinei.ibsoftcloud.com.br/chathub-sender/ixc/' \
  --data-urlencode 'user=USUARIO_IXC' \
  --data-urlencode 'pw=SENHA_IXC' \
  --data-urlencode 'dest=5575982479788' \
  --data-urlencode 'text=[template_name]=aviso_simples||[body.nome_cliente]=Jose Augusto Silva'
```

Tambem sao aceitos `POST application/x-www-form-urlencoded`,
`POST application/json` e media types terminados em `+json`. Query e corpo
podem ser combinados, mas o mesmo campo nao pode ter valores conflitantes.
Outros metodos retornam `405` com `Allow: GET, POST`; um `Content-Type` de POST
nao suportado retorna `415`.

O `dest` pode conter mascara, espacos e `+`. Se `text` repetir o destinatario
em `to`, `recipient`, `destinatario`, `numero_destino` ou `telefone_destino`, o
numero precisa coincidir com `dest`; esses aliases sao removidos antes da
montagem do template. Assim, credenciais e envelope IXC nunca entram nos
componentes persistidos para a Meta.

Ao criar uma instancia IXC, o backend gera:

- usuario estavel no formato `ixc_<id_da_instancia>`, com prefixo declarado no
  registro do tipo de instancia;
- senha aleatoria, armazenada somente como SHA-256 na coluna de credencial ja
  existente;
- exibicao da senha em texto puro somente na criacao ou rotacao.

Listagens administrativas retornam apenas usuario e dica mascarada da senha.
Nao existe coluna nova para IXC, payload bruto, usuario ou senha em texto puro.
Os quatro nomes do envelope sao filtrados de forma exata nos logs Rails, sem
ocultar parametros normais do Chatwoot como `username` ou `user_id`.
Para reduzir exposicao da senha em logs de proxy, prefira POST em producao,
embora GET seja mantido por compatibilidade com o contrato do ERP.

Depois da validacao do envelope, `text` segue pelo mesmo parser semantico,
builders, persistencia, fila Sidekiq, rate limiter e cliente Meta usados pelo
SGP. O IXC nao cria conversa no Chatwoot e nao realiza chamadas ao ERP.

Ordens criadas pelo contrato IXC podem ser atualizadas pela rota publica da
familia em `/chathub-sender/ixc/pedido/`. A atualizacao preserva exatamente o
mesmo envelope `user`, `pw`, `dest` e `text` usado no envio de mensagens. Os
campos semanticos da ordem ficam dentro de `text`.

## Contrato de atualizacao de pedido

Atualizacoes de ordem e pagamento usam:

```http
GET|POST /chathub-sender/sgp/pedido/
GET|POST /chathub-sender/ixc/pedido/
```

Cada caminho pertence a uma familia e nao a um contrato especifico. Assim, uma
ordem criada por `sgp_generic` ou por um futuro `sgp_standard` usa a rota SGP;
contratos IXC usam a rota IXC. Em todos os casos, conta e canal da credencial
precisam coincidir com a ordem.

Autenticacao:

- na rota SGP, use `Authorization: Bearer TOKEN` para `POST`;
- na rota SGP, `token=TOKEN` tambem e aceito em `GET` por compatibilidade;
- na rota IXC, envie `user` e `pw` no envelope obrigatorio;
- token SGP nao autentica a rota IXC e credenciais IXC nao autenticam a rota
  SGP.

Formatos:

- SGP aceita `GET` com campos escalares, `POST text/plain` no formato
  `[campo]=valor||[outro]=valor` e `POST application/json`;
- IXC aceita `GET`, `POST application/x-www-form-urlencoded` e
  `POST application/json`, sempre com `user`, `pw`, `dest` e `text`;
- no IXC, `text` contem os campos semanticos no formato
  `[campo]=valor||[outro]=valor`;
- limite de 64 KiB;
- campos desconhecidos sao rejeitados.

Identificacao da ordem:

- `fatura_id`, `id_fatura`, `id-fatura` ou `reference_id`.

Estado:

- atalho `status`;
- `order_status` ou `status_pedido`;
- `payment_status` ou `status_pagamento`;
- aliases em portugues sao normalizados;
- `message`/`mensagem` e `description`/`descricao` sao opcionais;
- `payment_timestamp` e opcional e exige um estado de pagamento.

Cada instancia possui mensagens padrao para os seis estados da ordem, os tres
estados de pagamento e o caso combinado de pagamento confirmado com ordem
concluida. O administrador pode edita-las na aba `Mensagens` da configuracao de
ordens. O marcador `{{reference_id}}` e substituido pela referencia real antes
do envio. Se o ERP informar `message` ou `mensagem`, o valor da requisicao tem
prioridade somente naquele envio. Instancias antigas usam os textos traduzidos
do modulo ate que um administrador salve personalizacoes.

Exemplo:

```bash
curl --get 'https://josinei.ibsoftcloud.com.br/chathub-sender/sgp/pedido/' \
  --data-urlencode 'fatura_id=9388' \
  --data-urlencode 'status=pago' \
  --data-urlencode 'token=TOKEN_DO_ENDPOINT'
```

O mesmo estado para uma ordem criada pelo IXC:

```bash
curl --get 'https://josinei.ibsoftcloud.com.br/chathub-sender/ixc/pedido/' \
  --data-urlencode 'user=USUARIO_IXC' \
  --data-urlencode 'pw=SENHA_IXC' \
  --data-urlencode 'dest=5575982479788' \
  --data-urlencode 'text=[fatura_id]=9388||[status]=pago'
```

O endpoint valida e persiste a solicitacao antes de responder `202`. O envio
visivel `interactive/order_status` ocorre no Sidekiq. Se a ordem ja possui os
estados solicitados, a resposta e `200 unchanged` e nenhuma mensagem e
enviada. A ordem precisa ter sido aceita pela Meta antes de receber
atualizacoes. No contrato IXC, `dest` tambem precisa coincidir com o
destinatario da mensagem que abriu a ordem.

## Interpretacao semantica

A API nao recebe nem encaminha `components` da Meta. O ERP informa dados
semanticos; os parsers e builders privados validam os valores e constroem
internamente `header`, `body`, botoes e `ORDER_DETAILS`.

Campos principais:

- `template_name`: nome aprovado na Meta;
- `template_language`: idioma, com `pt_BR` como padrao;
- `template_type`: `simple` ou `order`;
- `header_type`: alias de `header.type`;
- `header_link`: alias de `header.link`;
- `header_append_pdf`: alias de `header.append_pdf`;
- `header.type`: `text`, `document`, `image` ou `video`;
- `header.link`: URL HTTPS de midia;
- `header.variable.<nome>` ou `header.variable.1`: variavel de cabecalho;
- `body.<nome>`: parametros nomeados;
- `body.1`, `body.2`, ...: parametros posicionais continuos;
- `button.<indice>.type`: `url`, `copy_code` ou `quick_reply`;
- `button.<indice>.value`: valor do botao dinamico;
- `order.*`: referencia, total, moeda, itens, impostos, frete, desconto,
  expiracao e meios de pagamento PIX/boleto.

### Campos base

Os parametros externos `msg`, `to` e `token` sao sempre obrigatorios.
Dentro de `msg`, os campos base sao:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `template_name` | obrigatorio | nome exato aprovado na Meta, em minusculas, numeros e sublinhado |
| `template_language` | opcional | usa `pt_BR` quando omitido |
| `template_type` | opcional em mensagens comuns | usa `simple` quando omitido; informe `order` para ordens |
| `tipo-canal` | opcional | quando enviado, precisa ser `whatsapp-cloud` |
| `id-canal` | opcional | aceito para compatibilidade; a instancia continua definindo o canal real |

O modulo valida a estrutura e os tipos. Os nomes, a quantidade e a ordem das
variaveis ainda precisam corresponder ao template aprovado; uma divergencia e
rejeitada pela Meta.

### Variaveis de cabecalho e corpo

Cabecalho textual:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `header.variable.<nome>` | condicional | unica variavel nomeada do cabecalho |
| `header.variable.1` | condicional | unica variavel posicional do cabecalho |
| `header_text` ou `header.text` | condicional | alias para o valor textual |
| `header.parameter_name` | condicional | nome da variavel quando `header_text` for usado em template nomeado |

O cabecalho aceita somente uma variavel textual. Nao se pode combinar
`header.variable.*` com `header_text`, nem combinar cabecalho textual com
`header_link`.

Corpo:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `body.<nome>` | condicional | variavel nomeada, por exemplo `body.nome_cliente` |
| `body.1`, `body.2`, ... | condicional | variaveis posicionais continuas iniciadas em `1` |

Variaveis nomeadas e posicionais nao podem ser misturadas. Valores vazios sao
rejeitados.

### Cabecalho por link

Todos os links devem usar HTTPS, ter certificado valido e ser acessiveis pela
Meta sem autenticacao.

Documento ou PDF:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `header_link` ou `header.link` | obrigatorio | URL publica do documento |
| `header_type=document` | condicional | pode ser inferido quando o caminho termina em `.pdf`; recomenda-se informar |
| `header_filename` | opcional | nome apresentado; por padrao e extraido da URL |
| `header_append_pdf` | opcional | booleano que acrescenta `.pdf` ao caminho |
| `header_pdf_mode` | opcional | alternativa com `as_is` ou `append` |

`header_append_pdf` e `header_pdf_mode` nao podem definir comportamentos
conflitantes. O modo `append` nao altera uma URL cujo caminho ja termina em
`.pdf`.

Imagem ou video:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `header_link` ou `header.link` | obrigatorio | URL publica da midia |
| `header_type=image` | condicional | pode ser inferido para `jpg`, `jpeg`, `png` e `webp` |
| `header_type=video` | condicional | pode ser inferido para `mp4` e `3gp` |

Cabecalhos de imagem e video nao aceitam variavel textual, nome de arquivo ou
opcoes de PDF.

### Botoes dinamicos

Cada botao usa um indice entre `0` e `9`:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `button.<indice>.type` | obrigatorio | `url`, `copy_code` ou `quick_reply` |
| `button.<indice>.value` | obrigatorio | sufixo da URL, codigo ou payload conforme o tipo |

Indice e tipo precisam corresponder ao botao aprovado no template.

### Ordem e pagamento

Campos minimos de uma ordem:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `template_type=order` | obrigatorio | habilita `ORDER_DETAILS` |
| `order.reference_id` | obrigatorio | ID unico da ordem/fatura no canal, com ate 60 caracteres |
| `order.total` | obrigatorio | valor monetario positivo |
| `order.item_name` | opcional | usa `Fatura` quando nao existe lista de itens |
| `order.payment.pix.code` | condicional | obrigatorio quando PIX e usado |
| `order.payment.boleto.digitable_line` | condicional | obrigatorio quando boleto e usado |

Pelo menos um meio de pagamento precisa ser informado. PIX e boleto podem ser
enviados juntos.

#### Dois botoes de pagamento: PIX e codigo de barras

Para a Meta apresentar PIX como primeira opcao e o codigo de barras como
segunda opcao de pagamento, envie os dois campos na mesma solicitacao:

```text
[order.payment.pix.code]=PIX_COPIA_E_COLA_COMPLETO||
[order.payment.boleto.digitable_line]=00190000090350182490218767625173516510000006499
```

O backend inclui os meios em `payment_settings` na ordem PIX e boleto. Nao use
`button.1.type` ou `button.1.value` para criar o botao do codigo de barras:
ambos os pagamentos pertencem ao mesmo componente `ORDER_DETAILS`.
`order.button_index` indica somente em qual posicao do template aprovado esta o
botao de detalhes da ordem.

Para enviar somente o codigo de barras, omita todos os campos
`order.payment.pix.*` e informe apenas
`order.payment.boleto.digitable_line`. Para enviar somente PIX, faca o inverso.

Quando PIX e usado:

| Campo | Obrigatoriedade | Regra |
| --- | --- | --- |
| `order.payment.pix.merchant_name` | condicional | obrigatorio apos considerar o default da instancia |
| `order.payment.pix.key` | condicional | obrigatorio apos considerar o default protegido |
| `order.payment.pix.key_type` | condicional | `CPF`, `CNPJ`, `EMAIL`, `PHONE` ou `EVP` |

Os valores da solicitacao prevalecem sobre os defaults da instancia.

Para varios itens, use indices continuos iniciados em `0` e envie os quatro
campos de cada item:

- `order.items.<indice>.id`;
- `order.items.<indice>.name`;
- `order.items.<indice>.amount`;
- `order.items.<indice>.quantity`.

Resumo financeiro opcional:

- `order.subtotal`;
- `order.tax` e `order.tax_description`;
- `order.shipping` e `order.shipping_description`;
- `order.discount`, `order.discount_description` e
  `order.discount_program_name`;
- `order.expiration_at` e `order.expiration_description`;
- `order.currency`, com `BRL` como padrao;
- `order.goods_type`, com `digital-goods` como padrao;
- `order.button_index`, com `0` como padrao.

`order.expiration_at` aceita timestamp Unix ou ISO 8601 com fuso e precisa
estar no futuro. A descricao de expiracao sem data e rejeitada.

Valores monetarios brasileiros, por exemplo `R$ 1.234,56`, sao convertidos
para unidades menores (`123456`, offset `100`). URLs de midia devem ser HTTPS,
indices sao validados e o total de uma ordem deve corresponder a:

```text
subtotal + impostos + frete - desconto
```

Uma ordem exige `order.reference_id`, `order.total` e ao menos
`order.payment.pix.code` ou
`order.payment.boleto.digitable_line`. Quando o PIX e usado, `merchant_name`,
`key` e `key_type` podem ser informados pelo ERP ou herdados dos dados PIX
padrao da instancia.

Os valores da requisicao sempre possuem prioridade. A instancia preenche
somente campos ausentes ou vazios. Se, depois dessa composicao, uma ordem com
PIX continuar sem algum dos tres dados, a solicitacao e rejeitada antes de
entrar na fila.

Os defaults ficam na aba **Ordens** da instancia e sao editados em modal. A
interface nunca devolve a chave integral: informa apenas se ela existe e uma
dica com os quatro ultimos caracteres.

## Resposta assincrona

Resposta `202 Accepted`:

```json
{
  "ok": true,
  "status": "accepted",
  "message": "Solicitacao aceita para processamento.",
  "message_id": null,
  "delivery_id": 42,
  "template_name": "lembrete_fatura_pdf_pix",
  "template_type": "order",
  "reference_id": "9388"
}
```

`message_id` e `null` nessa resposta porque a chamada web nao espera a Meta. O
worker envia o template depois e grava o ID retornado pela Meta em
`meta_message_id`. O resultado pode ser acompanhado no historico administrativo
da tela **API de cobranca**.

Para templates comuns, cada chamada cria uma entrega independente. Para
templates `order`, `order.reference_id` identifica uma unica ordem canonica na
instancia. Quando o reenvio esta habilitado, repetir a referencia para o mesmo
destinatario cria outra entrega e outro job, vinculados a essa ordem. O novo
envio pode usar o mesmo template ou outro template de cobranca.

O ERP nao envia identificador adicional: referencias iguais significam
obrigatoriamente a mesma ordem. Por isso, uma repeticao de uma chamada que ja
recebeu `202 Accepted` e tratada como um novo envio intencional. O ERP so deve
repetir a requisicao quando realmente desejar reenviar a cobranca.

A instancia rejeita o reenvio com `409 Conflict` quando a opcao administrativa
esta desabilitada, quando a referencia pertence a outro destinatario ou quando
a ordem ja esta paga, concluida ou cancelada. A mesma referencia pode existir
em outra instancia sem conflito.

## Persistencia

Migration:

- `db/migrate/20260727090000_create_ibsoft_external_messaging.rb`.
- `db/migrate/20260727213000_add_instance_type_to_ibsoft_external_message_endpoints.rb`.
- `db/migrate/20260728100000_create_ibsoft_external_message_orders.rb`.
- `db/migrate/20260729100000_add_order_pix_defaults_to_ibsoft_external_messaging.rb`.
- `db/migrate/20260729130000_add_external_messaging_retention_and_manual_order_updates.rb`.
- `db/migrate/20260729170000_add_order_update_messages_to_ibsoft_external_messaging.rb`.
- `db/migrate/20260805190000_enable_ibsoft_external_order_resends.rb`.

Tabelas:

- `ibsoft_external_message_endpoints`;
- `ibsoft_external_message_deliveries`;
- `ibsoft_external_message_orders`;
- `ibsoft_external_message_order_updates`.

A instancia armazena conta, canal, criador, tipo, nome, SHA-256 do segredo de
autenticacao, dica nao sensivel, estado, limite de envio, politica de reenvio
de ordens, os tres defaults PIX opcionais e somente as mensagens de atualizacao
personalizadas pelo administrador. O usuario IXC e derivado do ID da instancia
e nao ocupa uma coluna. A coluna JSONB
aceita exclusivamente as dez chaves conhecidas e cada texto e limitado a 1024
bytes. Textos nao personalizados continuam vindo dos arquivos de traducao. A
chave PIX usa Active Record Encryption e nunca faz parte do payload
administrativo.
O nome tecnico da tabela e do model continua usando `endpoint`, preservando o
contrato interno ja implantado. `InstanceTypeRegistry` e a fonte de verdade
backend para o caminho publico, que e devolvido no campo `public_path` da API
administrativa e usado pela interface.

A entrega armazena somente informacoes operacionais: conta, canal, endpoint,
identidade e fingerprint internos, destinatario, template, conteudo textual
renderizado, referencia de ordem/fatura, estado, ID da Meta, erro, contador e
timestamps.

O payload bruto e as credenciais da Meta nao sao armazenados. Os componentes
normalizados existem somente enquanto o registro aguarda o worker, pois sao
necessarios para sobreviver a reinicios e auto scaling. A chave PIX e extraida
do JSON, armazenada separadamente em uma coluna criptografada e materializada
somente em memoria imediatamente antes da chamada para a Meta. Depois da
tentativa final (`accepted`, `failed` ou `uncertain`), componentes e snapshot
da chave sao apagados.

`ibsoft_external_message_orders` guarda somente a identidade canonica da ordem,
o envio inicial e os estados atuais de ordem/pagamento. A unicidade usa
`endpoint_id + reference_id`, permitindo o mesmo ID em outras instancias.
Cada entrega de cobranca aponta para essa ordem por `order_id`; assim, o
historico registra todos os templates enviados sem duplicar o estado da ordem.
O destinatario canonico e o da entrega inicial e nao pode mudar nos reenvios.

`ibsoft_external_message_order_updates` e ao mesmo tempo a fila duravel e a
auditoria minima de cada mensagem de atualizacao. Armazena apenas estados
solicitados, texto visivel, descricao, timestamp de pagamento, estado
operacional, ID/erro da Meta, contador e timestamps. O corpo HTTP original nao
e armazenado. Atualizacoes manuais tambem guardam a origem `manual` e o usuario
que solicitou a operacao; chamadas do ERP usam a origem `external_api`.

## Consulta e atualizacao manual

A aba **Ordens** da instancia lista somente as ordens pertencentes a conta,
canal e instancia selecionados. A API administrativa aceita:

- destinatario, com busca parcial pelos digitos;
- referencia da ordem, com busca parcial;
- status da ordem;
- status do pagamento;
- data inicial e final;
- pagina e quantidade por pagina, limitada a 100.

O usuario pode selecionar uma ordem, todas as ordens atualizaveis da pagina ou
todas as ordens atualizaveis do filtro. A selecao de todo o filtro nao envia
uma lista extensa de IDs. O servidor registra os filtros e um timestamp de
corte, conta os registros elegiveis e os processa em lotes de 100 por
`BulkOrderUpdateJob`. Ordens criadas depois da confirmacao nao entram
acidentalmente na operacao.

Uma ordem nao pode ser atualizada manualmente enquanto nenhum de seus envios
foi aceito pela Meta ou quando existe uma atualizacao com resultado
`uncertain`. Assim, um reenvio aceito pode habilitar a atualizacao mesmo se a
primeira tentativa falhou. O update manual usa o mesmo `OrderUpdateCreator`,
`SendOrderUpdateJob`, lock por ordem, rate limiter e contrato da Meta usados
pelas atualizacoes originadas no ERP. Assim, operacoes manuais e externas
preservam a mesma ordem e nao competem por caminhos paralelos.

## Retencao

Cada instancia possui `retention_days`, com default de 30 dias e faixa valida
de 1 a 3650. O valor e configurado no modal da instancia, e nao por variavel de
ambiente, porque contas e canais podem exigir politicas diferentes.

`CleanupExpiredRecordsJob` roda diariamente na fila `scheduled_jobs`. Um lock
no Redis garante que apenas uma replica agende a varredura em ambientes com
auto scaling. Cada instancia recebe um `CleanupEndpointRecordsJob` na fila
`purgable`, protegido por lock proprio. Assim, as instancias podem ser limpas
em paralelo por varias replicas sem concorrencia sobre os mesmos registros. A
limpeza opera em lotes de 500 e segue esta ordem:

1. remove todas as atualizacoes vinculadas a ordens expiradas;
2. remove as ordens expiradas;
3. remove atualizacoes antigas que permaneceram sem a ordem expirar;
4. remove entregas antigas que nao estejam mais referenciadas.

A retencao e absoluta e independe do estado operacional. Entregas e
atualizacoes mais antigas que o prazo da instancia sao eliminadas mesmo quando
estao `queued`, `processing` ou `uncertain`. Uma ordem usa sua ultima atividade
como referencia; cada reenvio atualiza esse relogio para preservar a identidade
canonica enquanto ainda ha cobrancas recentes. A entrega inicial permanece
protegida enquanto a ordem existir. Jobs antigos encerram sem erro quando o
registro ja foi removido. Depois do prazo nao existe mais tentativa de envio
nem possibilidade de conciliacao tardia para aquele registro. O payload bruto
continua inexistente; a politica remove o historico operacional minimo conforme
o prazo definido pelo administrador.

## Processamento assincrono

1. A rota informa o tipo ao `InstanceTypeRegistry`.
2. O parser registrado le o envelope SGP (`msg`, `to`, `token`) ou IXC
   (`user`, `pw`, `dest`, `text`).
3. `EndpointAuthenticator` valida o segredo e impede que credenciais de um
   contrato sejam usadas na rota de outro.
4. `FieldPayloadParser` interpreta os campos semanticos.
5. `OrderDefaultsMerger` completa os dados PIX ausentes com os defaults da
   instancia.
6. `TemplatePayloadBuilder` monta componentes conhecidos da Meta.
7. `OrderPixSecret` separa a chave do JSON que sera persistido.
8. `RequestIdentityKey` gera a identidade tecnica interna.
9. `DeliveryCreator` cria o registro `queued`; para cobrancas repetidas, trava
   e reutiliza a ordem canonica da instancia.
10. `SendDeliveryJob` entra na fila `medium`.
11. `DeliverySender` adquire o registro por update condicional.
12. `RateLimiter` aplica o limite por canal no Redis compartilhado.
13. `MetaClient` materializa a chave em memoria e envia diretamente para
    `/{phone_number_id}/messages`.
14. `messages[0].id` marca o registro como `accepted` e elimina os dados
    transitorios.
15. Webhooks avancam para `sent`, `delivered`, `read` ou `failed`.

`DispatchPendingJob` roda a cada minuto na fila `scheduled_jobs` e recupera
registros persistidos cujo enqueue inicial falhou. Um registro em `processing`
por mais de 15 minutos vira `uncertain` e nao e reenviado.

Essa decisao evita duplicidade: a Meta nao oferece chave idempotente no
endpoint de mensagens, entao um timeout pode ocorrer depois do aceite.

Para atualizacoes de pedido:

1. `OrderUpdateInboundRequest` seleciona o contrato pela familia da rota;
2. no SGP, `OrderUpdateCredentials` e `OrderStatusRequestParser` extraem token
   e campos diretos;
3. no IXC, `IxcInboundRequestParser` valida `user`, `pw`, `dest` e `text`;
4. `EndpointAuthenticator` valida a credencial e impede cruzamento de familia;
5. `OrderStatusContract` normaliza aliases e valida estados;
6. `OrderUpdateCreator` localiza a ordem pela conta e canal da instancia e,
   no IXC, tambem pelo destinatario;
7. uma trava no registro da ordem calcula o estado projetado da fila;
8. repeticoes do mesmo estado sao deduplicadas;
9. `SendOrderUpdateJob` envia pela fila `medium`;
10. `OrderUpdateSender` processa somente a primeira atualizacao pendente da
   ordem;
11. `MetaClient` envia `interactive/order_status`;
12. o estado canonico so avanca depois do aceite da Meta;
13. webhooks avancam a atualizacao para `sent`, `delivered`, `read` ou
    `failed`.

Para atualizacoes manuais em massa, `BulkOrderUpdateScheduler` valida a selecao
e cria um unico job inicial. `BulkOrderUpdateJob` consulta no maximo 100 ordens,
cria a atualizacao de cada uma pelo fluxo normal e encadeia o proximo lote pelo
ultimo ID processado.

Atualizacoes de ordens diferentes podem ser processadas em paralelo. Uma mesma
ordem e serializada pelo PostgreSQL, mesmo com varios workers e replicas. Um
resultado `uncertain` bloqueia as atualizacoes seguintes da ordem para evitar
avancar sobre um estado desconhecido.

## Escala e nuvem

- PostgreSQL e a fonte de verdade duravel;
- Redis compartilhado controla vazao por canal, com criacao atomica da janela
  e do respectivo TTL;
- Sidekiq executa envios fora da requisicao web;
- claim condicional impede dois workers de enviarem o mesmo registro;
- jobs duplicados sao seguros porque somente `queued` pode ser adquirido;
- locks por ordem preservam a sequencia entre atualizacoes concorrentes;
- selecoes em massa usam filtros compactos, timestamp de corte e lotes
  encadeados, sem manter milhares de IDs em memoria ou nos argumentos Sidekiq;
- a fila de recuperacao seleciona apenas a primeira atualizacao de cada ordem;
- a limpeza usa lock Redis global no agendamento, lock por instancia, jobs
  distribuidos e lotes de banco;
- nenhum estado funcional depende de memoria local;
- varios containers Rails e Sidekiq podem operar simultaneamente;
- a credencial externa nao carrega segredo da Meta e pode ser rotacionada;
- o limite por canal agrega varios endpoints vinculados ao mesmo numero.

Em auto scaling, Rails, Sidekiq e scheduler devem compartilhar PostgreSQL e
Redis. O proxy deve aplicar limites adicionais de requisicao, URL e query
string. Como SGP usa GET e IXC pode usar GET, o limite de URL do proxy precisa
comportar os templates usados pelos ERPs. Para IXC, POST e recomendado para
evitar senha na URL e nos access logs intermediarios.

## Estrutura

Backend:

- `app/models/ibsoft/external_messaging/`;
- `app/services/ibsoft/external_messaging/`;
- `app/services/ibsoft/external_messaging/order_update_credentials.rb`:
  extracao limitada e sem persistencia de Bearer/token SGP;
- `app/services/ibsoft/external_messaging/order_update_inbound_request.rb`:
  adapta o contrato SGP ou o envelope IXC para a mesma regra de atualizacao;
- `app/services/ibsoft/external_messaging/endpoint_authenticator.rb`:
  autenticacao por contrato exato nas mensagens e por familia nas ordens;
- `app/jobs/ibsoft/external_messaging/`;
- `app/controllers/api/v1/ibsoft/external_messaging/`;
- `app/controllers/api/v1/accounts/ibsoft/external_messaging/`.

Frontend:

- `app/javascript/dashboard/ibsoft/externalMessaging/`;
- `instanceTypes.js`: catalogo frontend dos tipos suportados, incluindo marca
  visual e traducoes de cada contrato;
- `integrationContracts.js`: adaptador de apresentacao dos envelopes SGP e
  IXC, sem condicionais espalhadas pela interface;
- `components/InstanceCard.vue`: resumo operacional de uma instancia;
- `components/InstanceTypeMark.vue`: alternancia de logo por tema, com fallback
  para icone dos tipos sem marca propria;
- `components/InstanceEditorDialog.vue`: criacao em duas etapas e edicao;
- `components/CredentialsDialog.vue`: consulta segura da identificacao parcial
  da credencial ativa e comando explicito para rotacao;
- `components/InstanceDetail.vue`: visao geral, ordens, instrucoes e historico;
- `components/OrdersPanel.vue`: filtros, tabela paginada, selecao e
  atualizacao manual de ordens;
- `components/BulkOrderUpdateDialog.vue`: definicao dos novos estados para a
  selecao;
- `components/IntegrationInstructions.vue`: guia por cenarios com campos,
  obrigatoriedade, regras e exemplos executaveis do contrato;
- `components/OrderDefaultsDialog.vue`: edicao isolada dos defaults PIX;
- `app/javascript/dashboard/ibsoft/assets/images/logo/sgp/`: logos SGP para os
  temas claro e escuro;
- `app/javascript/dashboard/ibsoft/assets/images/logo/ixc/`: logos IXC para os
  temas claro e escuro;
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`:
  registro da tela no menu privado de configuracoes;
- `app/javascript/dashboard/i18n/locale/*/ibsoftExternalMessaging.json`.

Somente administradores podem abrir a tela. O catalogo inicial exibe as
instancias em cards e nao consulta entregas. Criacao e edicao usam modal; a
criacao escolhe primeiro o tipo. A visualizacao de uma instancia possui visao
geral, ordens, instrucoes e historico. As instrucoes separam mensagem simples,
variaveis, documento, midia, botoes, ordem e atualizacao de ordem, evitando um
unico exemplo ambiguo. O historico paginado e consultado somente ao abrir sua
aba e sempre filtrado pela instancia selecionada. Historico e ordens usam 25
itens por pagina como padrao e permitem selecionar 10, 25, 50 ou 100 itens.

Tipo e canal sao imutaveis depois da criacao. Essa restricao evita converter
silenciosamente uma integracao ativa para outro contrato. Nome, limite e estado
continuam editaveis.

Os modais do modulo limitam a altura ao viewport e possuem rolagem vertical
propria, preservando conteudo e acoes em telas menores. O icone de credenciais
abre apenas os metadados seguros da credencial ativa. O segredo completo nao e
recuperavel; somente o comando explicito **Gerar novas credenciais** invalida o
segredo anterior e exibe o novo valor uma unica vez.

## Pontos de acoplamento

Pontos de conexao com o Chatwoot:

- `config/routes.rb`: rotas publicas vinculadas explicitamente aos tipos SGP e
  IXC, as rotas compartilhadas de pedido de cada familia e rotas
  administrativas;
- `config/schedule.yml`: jobs de recuperacao e retencao;
- `app/javascript/dashboard/routes/dashboard/dashboard.routes.js`: rota;
- `app/javascript/dashboard/ibsoft/chathubSettings/settingsSections.js`: menu
  administrativo privado do ChatHub, sem novo toque na sidebar nativa;
- indexes i18n `en` e `pt_BR`: traducoes;
- `db/schema.rb`: migration.

O status usa extensao privada:

- `config/initializers/ibsoft_external_messaging.rb`;
- `config/initializers/ibsoft_external_messaging_parameter_filter.rb`;
- `app/services/ibsoft/external_messaging/whatsapp_status_extension.rb`.

Nenhum service de envio, model de conversa, model de mensagem ou controller de
webhook do Chatwoot foi editado.

## Variaveis

Nativas:

- `WHATSAPP_CLOUD_BASE_URL`, default `https://graph.facebook.com`;
- `WHATSAPP_API_VERSION`, lida via `GlobalConfigService`.

Privada opcional:

- `IBSOFT_EXTERNAL_MESSAGING_META_TIMEOUT_SECONDS`, default `20`, limitada
  entre 5 e 60 segundos.

Nao existe variavel Ibsoft nova. Para salvar ou processar chaves PIX em
producao, as tres variaveis nativas de Active Record Encryption precisam estar
configuradas. Endpoints inativos recusam requisicoes.

## Testes

```bash
bundle exec rspec \
  spec/models/ibsoft/external_messaging \
  spec/services/ibsoft/external_messaging \
  spec/jobs/ibsoft/external_messaging \
  spec/requests/api/v1/ibsoft/external_messaging \
  spec/requests/api/v1/accounts/ibsoft/external_messaging
```

```bash
pnpm exec vitest run \
  app/javascript/dashboard/ibsoft/externalMessaging/specs \
  --no-coverage
```

As respostas da Meta sao simuladas com WebMock. Os testes nao enviam mensagens
reais.

## Atualizacao do upstream

1. Revisar os pontos de acoplamento listados acima.
2. Confirmar se `Whatsapp::IncomingMessageBaseService#process_statuses` ainda
   recebe `@processed_params[:statuses]` e possui `inbox`.
3. Confirmar o contrato de `Channel::Whatsapp#provider_config`.
4. Preservar as rotas publicas, as rotas administrativas e o registro
   `InstanceTypeRegistry`, incluindo `family`, `public_path`,
   `order_update_path`, estrategia de autenticacao, prefixo de usuario, parser
   e contrato.
5. Confirmar as entradas privadas de recuperacao e limpeza em
   `config/schedule.yml`.
6. Rodar migration, specs, RuboCop, ESLint e teste frontend.
7. Testar token SGP, usuario/senha IXC, aceite assincrono, atualizacao manual,
   retencao e webhook em homologacao.

Se o Chatwoot oferecer envio direto equivalente, comparar contratos e migrar
os registros antes de remover o modulo.
