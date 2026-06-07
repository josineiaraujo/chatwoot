# Ibsoft Theme Patch

Patch visual privado para personalizar a experiencia do dashboard Chatwoot sem
misturar regra de negocio com o core do produto.

## Objetivo

- Aplicar identidade visual propria da Ibsoft/ChatHub.
- Manter a customizacao concentrada em `app/javascript/dashboard/ibsoft/theme`.
- Reduzir conflitos ao receber atualizacoes do Chatwoot oficial.
- Evitar alteracoes espalhadas em componentes centrais quando uma sobrescrita de
  tema resolver o caso.

## Escopo atual

- Gradiente global para o modo escuro.
- Ajustes de fundo em paineis principais do dashboard.
- Estilo premium para conversas selecionadas.
- Estilo premium para salas/chats selecionados do chat interno.
- Logos ChatHub em empty states de conversas.
- Ajustes visuais do topo da sidebar.

## Arquivos do patch

- `_dark-overrides.scss`: tokens privados, gradiente escuro e sobrescritas
  visuais.
- `assets/chathub-logo-color.png`: logo ChatHub para tema claro.
- `assets/chathub-logo-white.png`: logo ChatHub para tema escuro.

## Pontos de acoplamento no Chatwoot

- `app/javascript/dashboard/assets/scss/app.scss`: importa o patch SCSS.
- `app/javascript/dashboard/components/widgets/conversation/EmptyState/EmptyState.vue`:
  adiciona classes estaveis para substituir icones por logos do patch.
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`: ajusta topo da
  sidebar, botao de recolher/expandir e abertura inicial recolhida.
- `app/javascript/dashboard/components-next/sidebar/SidebarAccountSwitcher.vue`:
  aumenta o logo compacto no estado recolhido.
- `app/javascript/dashboard/ibsoft/internalChat/views/InternalChat.vue`: adiciona
  classe estavel para item selecionado do chat interno.
- `app/javascript/dashboard/i18n/locale/*/ibsoftTheme.json`: traducoes
  especificas do patch.
- `app/javascript/dashboard/i18n/locale/*/index.js`: registra as traducoes do
  patch.

## Regras para evoluir este patch

- Nao adicionar regra de negocio aqui.
- Nao escrever texto user-facing direto em componentes.
- Preferir variaveis CSS e tokens existentes; hardcoded colors so devem ficar
  concentradas nos tokens privados do patch.
- Se precisar tocar em componente original, manter a mudanca pequena e
  documentada nesta lista de acoplamentos.
- Nao misturar alteracoes deste patch com modulos privados como chat interno ou
  ERP no mesmo commit, salvo quando for apenas uma classe visual compartilhada.

## Validacao recomendada

- Rodar ESLint nos componentes tocados.
- Verificar tema claro e escuro.
- Verificar sidebar recolhida/expandida.
- Verificar conversas, mencoes, nao atendidas e empty state sem conversa
  selecionada.
- Verificar lista do chat interno com item selecionado.
