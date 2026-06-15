# Ibsoft Locale Patch

Patch privado para fazer datas, horarios e tempos relativos respeitarem o
locale ativo do Chatwoot.

## Objetivo

- Evitar datas em ingles quando a interface estiver em portugues.
- Centralizar formatacao de datas e tempos relativos em um ponto privado.
- Reduzir alteracoes espalhadas em componentes do Chatwoot.
- Manter fallback compativel com o comportamento original em ingles.

## Escopo atual

- Horario de mensagens e tooltips de mensagens.
- Datas de galeria/anexos, busca, inbox, conversas e arquivos compartilhados.
- Tempo relativo longo, como `ha cerca de 1 mes`.
- Tempo relativo curto, como `1 mes`, `12 min`, `3 d`.
- Datas do date picker, relatorios, billing, eventos SLA, Shopify e email
  citado.

## Arquivos do patch

- `dateTime.js`: resolve o locale atual, aplica locale do `date-fns`, normaliza
  formatos de data/hora e converte tempos relativos para formato curto.

## Pontos de acoplamento no Chatwoot

- `app/javascript/shared/helpers/timeHelper.js`: delega formatacao de data,
  horario, tempo relativo e tempo curto para o patch.
- `app/javascript/shared/helpers/DateHelper.js`: delega `formatUnixDate` para o
  patch.
- `app/javascript/dashboard/App.vue`: sincroniza o locale ativo em
  `window.chatwootConfig.selectedLocale`.
- `app/javascript/dashboard/routes/dashboard/settings/profile/UserLanguageSelect.vue`:
  sincroniza mudancas de idioma do usuario.
- `app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`:
  sincroniza mudancas de idioma da conta.
- Componentes/helpers com `date-fns/format` direto foram alterados para usar
  `ibsoftFormatDate`.

## Regras para evoluir

- Nao formatar datas diretamente com `date-fns/format` em componentes.
- Usar `ibsoftFormatDate`, `ibsoftFormatDistanceToNow` ou os helpers centrais
  de `shared/helpers/timeHelper`.
- Antes de adicionar novo formato, incluir o mapeamento em `dateTime.js`.
- Manter fallback em ingles para reduzir risco em outros locales.
- Nao adicionar texto traduzivel aqui; este patch deve formatar datas e tempos,
  nao substituir arquivos i18n.

## Validacao recomendada

- Testar UI em `pt_BR` e `en`.
- Verificar bolhas de mensagem, tooltip de mensagem, lista de conversas, inbox,
  busca, arquivos compartilhados e snooze.
- Verificar se nao aparecem `May`, `AM/PM` ou `1mo` em portugues.
