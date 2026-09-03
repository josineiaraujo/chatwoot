# Localizacao Ibsoft

Este patch centraliza defaults de localizacao privados da instalacao Ibsoft sem
espalhar constantes pelo core do Chatwoot.

## Objetivo

- Usar `America/Sao_Paulo` como fuso padrao operacional.
- Evitar que a configuracao de horario de atendimento da inbox caia no default
  upstream `America/Los_Angeles`.
- Corrigir textos da tela de horario de atendimento por override de i18n, sem
  editar os arquivos oficiais de traducao do Chatwoot.
- Permitir intervalos/pausas dentro do horario de atendimento sem alterar a
  tabela nativa `working_hours`.

## Arquivos privados

- `app/javascript/dashboard/ibsoft/localization/defaultTimezone.js`: valor
  padrao frontend e helper para selecionar a option correspondente.
- `app/javascript/dashboard/ibsoft/localization/businessHoursDefaults.js`:
  defaults especificos da tela de horario de atendimento e normalizacao de
  valores legados (`UTC`, `America/Los_Angeles`, vazio) para Brasilia.
- `app/services/ibsoft/localization/default_timezone.rb`: valor padrao backend.
- `app/models/concerns/ibsoft/localization/account_default_timezone.rb`: define
  `account.reporting_timezone` quando uma conta e criada sem valor. O default
  nao e reaplicado em atualizacoes, preservando a semantica nativa de um valor
  posteriormente removido.
- `app/models/ibsoft/localization/working_hour_break.rb`: modelo das pausas por
  caixa/dia.
- `app/models/concerns/ibsoft/localization/inbox_working_hour_breaks.rb`:
  associacao, serializacao, atualizacao das pausas da inbox e invalidacao do
  cache nativo de inboxes.
- `app/models/concerns/ibsoft/localization/working_hour_break_aware.rb`:
  aplica pausas ao calculo de disponibilidade.
- `app/controllers/concerns/ibsoft/localization/inboxes_controller_working_hour_breaks.rb`:
  salva `ibsoft_working_hour_breaks` na atualizacao da inbox.
- `config/locales/zz_ibsoft_localization.*.yml`: mensagens backend do patch.
- `config/initializers/ibsoft_localization_defaults.rb`: registra callbacks
  `Rails.autoloaders.main.on_load` para conectar os concerns privados em
  `Account`, `Inbox`, `WorkingHour` e `InboxesController` somente quando cada
  constante for carregada. Isso preserva reloads e evita antecipar o
  carregamento de models nativos antes da inicializacao do i18n.
- `db/migrate/20260630090000_set_ibsoft_default_timezone.rb`: atualiza default
  de `inboxes.timezone` e dados existentes que ainda usam `UTC`,
  `America/Los_Angeles` ou valores vazios.
- `db/migrate/20260630091000_create_ibsoft_working_hour_breaks.rb`: cria a
  tabela `ibsoft_working_hour_breaks`.
- `app/javascript/dashboard/ibsoft/localization/workingHourBreaks.js`: converte
  pausas entre API e tela.
- `spec/models/ibsoft/localization/working_hour_break_spec.rb`: cobre validacao
  das pausas e impacto no calculo de disponibilidade.
- `spec/factories/ibsoft/localization/working_hour_breaks.rb`: factory da
  tabela privada de pausas.

## Pontos de acoplamento

- `app/views/api/v1/models/_inbox.json.jbuilder`,
  `app/views/public/api/v1/models/_inbox.json.jbuilder` e
  `app/views/api/v1/widget/configs/create.json.jbuilder`: expõem
  `ibsoft_working_hour_breaks`.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WeeklyAvailability.vue`:
  usa o helper Ibsoft para fallback de timezone, traduz nomes dos dias e envia
  pausas no payload da inbox.
- `app/javascript/dashboard/routes/dashboard/settings/inbox/components/BusinessDay.vue`:
  adiciona UI de intervalos por dia.
- `app/javascript/dashboard/routes/dashboard/onboarding/account-details/useAccountEnrichment.js`:
  usa `America/Sao_Paulo` quando a conta ainda nao possui timezone enriquecido.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: adiciona overrides
  de textos da tela de horario de atendimento.
- `app/javascript/widget/helpers/availabilityHelpers.js`,
  `app/javascript/widget/composables/useAvailability.js`,
  `app/javascript/widget/components/Availability/AvailabilityContainer.vue` e
  `app/javascript/widget/components/Availability/AvailabilityText.vue`:
  consideram pausas no calculo de disponibilidade do widget.

## Cuidados ao atualizar upstream

- Se o upstream alterar a tela `WeeklyAvailability.vue`, preservar apenas a
  delegacao para `businessHoursDefaults.js`.
- Se o upstream alterar a modelagem de `working_hours`, preservar a tabela de
  pausas como camada separada e manter apenas o ponto de conexao no calculo de
  disponibilidade.
- Se o upstream criar uma variavel oficial de timezone padrao, avaliar remover o
  initializer privado e manter apenas configuracao.
- Rodar `db:migrate` apos aplicar este patch para atualizar o default real no
  banco.
