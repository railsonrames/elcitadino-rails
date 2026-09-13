# Handoff: ElCitaDino — tema «Azul profundo + gris» (turno 6)

## Visão geral

Redesenho do app ElCitaDino (Rails 8 + Tailwind + Hotwire, PWA) em mobile-first.
A opção escolhida é o **turno 6** do documento de design: fundo cinza, cabeçalho azul
profundo, botões sólidos e o arranjo de informação do turno 2b (coluna de data à
esquerda, linhas separadas por réguas, etiquetas de status compactas, ações alinhadas
à esquerda). Raios intercalados: 8px em superfícies e botões, 0 em grade e linhas.

Telas cobertas: **Proveedores (Buscar)**, **Citas**, **Mi Agenda (painel do provedor)**.

> **Opção B em standby:** o turno 2 do mesmo arquivo é a versão no design system
> **Modernist** (Archivo, vermelho #ec3013 sobre #f3f2f2, raio 0, réguas de 2px).
> Ela fica preservada no arquivo de design e não deve ser apagada — é a segunda
> direção caso vocês queiram um visual mais editorial no futuro. Nada neste handoff
> impede a troca: só os tokens da seção «Design tokens» mudam.

## Sobre os arquivos de design

Os arquivos deste pacote são **referências de design escritas em HTML** — protótipos
que mostram aparência e comportamento pretendidos, **não** código de produção para
copiar. A tarefa é **recriar essas telas no ambiente do próprio app**: ERB +
Tailwind + Stimulus/Turbo, aproveitando os partials que já existem
(`app/views/appointments/_card.html.erb`, `app/views/dashboard/_calendar.html.erb`
etc.), não introduzir React nem um novo pipeline de CSS.

## Fidelidade

**Alta fidelidade (hifi).** Cores, tipografia, espaçamentos e estados estão
definidos com valores exatos abaixo. Recriar fielmente; onde houver conflito entre
o protótipo e um partial existente, preferir manter a estrutura do partial e trocar
apenas as classes.

## Design tokens

Fonte: **Archivo** (Google Fonts, pesos 400/600/800). Carregar no `<head>` do
layout (`app/views/layouts/application.html.erb`) ou via `@import` no CSS do
Tailwind. Substitui a stack padrão do Tailwind.

| Papel | Valor |
| --- | --- |
| Fundo da página (`bg`) | `#e6e8ed` |
| Superfície (cartões, barras) | `#ffffff` |
| Superfície secundária (coluna de data, cabeçalho de tabela) | `#f4f6fa` |
| Tinta principal (texto) | `#0d1626` |
| Texto secundário | `#5a6480` |
| Texto terciário / rótulos | `#67718a` |
| Linha divisória forte | `#d1d6e0` |
| Linha divisória interna | `#e2e6ee` |
| Linha da grade do calendário | `#d8dce5` |
| Borda de botão contornado | `#c3cad8` |
| Azul de ação | `#1546c6` |
| Azul de cabeçalho / hover do botão | `#0b2f87` |
| Verde de confirmação | `#157f3c` (hover `#0f6530`) |
| Verde sobre azul (cifra destacada) | `#6ee89b` |
| Vermelho de cancelamento (texto) | `#b3261e` (hover fundo `#fbeceb`) |
| Âmbar de aviso de pagamento | barra `#d97706`, fundo `#fdf4e5`, texto `#8a5206` |
| Dia desabilitado no calendário | `#a7afc0` |

Raios: `8px` (cartões, blocos), `6px` (botões, chips, blocos de data), `0`
(células do calendário e linhas de lista). Sem sombras — o contraste vem do fundo
cinza contra o branco.

Etiquetas de status (`padding:4px 8px; border-radius:4px; font:800 10px; uppercase`):

| Status | Fundo | Texto |
| --- | --- | --- |
| Pendiente | `#fff6e6` | `#b45309` |
| Confirmada | `#e7eeff` | `#1653d9` |
| Completada | `#e7f4ec` | `#15803d` |
| Cancelada | `#eef1f6` | `#5b6b85` |

Escala tipográfica usada:

- H1 de tela: `800 30px/1`, `letter-spacing:-.03em`
- Rótulo kicker: `700 10px`, `letter-spacing:.1em`, uppercase
- Nome em linha de lista: `800 15px/1.2`
- Corpo secundário: `400 13px`
- Numeral de data: `800 22px/1`; mês: `700 10px` uppercase; hora: `800 12px`
- Rótulo de botão: `800 12px`
- Rótulo de aba inferior: `700 10px`

## Como aplicar no app (Tailwind v4)

1. **Tokens.** No arquivo de entrada do Tailwind (`app/assets/tailwind/application.css`),
   declarar os tokens em `@theme` para poder usar `bg-surface`, `text-ink`,
   `border-line`, `bg-brand` etc.:

   ```css
   @import "tailwindcss";

   @theme {
     --font-sans: "Archivo", ui-sans-serif, system-ui, sans-serif;
     --color-ground: #e6e8ed;
     --color-surface: #ffffff;
     --color-surface-2: #f4f6fa;
     --color-ink: #0d1626;
     --color-ink-2: #5a6480;
     --color-ink-3: #67718a;
     --color-line: #d1d6e0;
     --color-line-2: #e2e6ee;
     --color-brand: #1546c6;
     --color-brand-deep: #0b2f87;
     --color-ok: #157f3c;
     --radius-card: 8px;
     --radius-btn: 6px;
   }
   ```

2. **Layout.** `app/views/layouts/application.html.erb`: `bg-ground text-ink font-sans`
   no `<body>`; trocar o `<main class="container mx-auto mt-10 px-5 pb-10">` por um
   container mobile-first (`mx-auto w-full max-w-[430px] px-3 pb-24`) e remover o
   `mt-10` — o cabeçalho azul passa a colar no topo. O `<footer>` de copyright sai
   das telas de app (fica só nas páginas públicas); no lugar dele entra a barra de
   abas fixa.

3. **Cabeçalho azul.** Substituir `app/views/layouts/_navbar.html.erb` por um header
   `bg-brand-deep text-white`: linha 1 = marca + sino (com badge) + seletor de idioma;
   depois o kicker, o H1 da tela e — quando houver — as abas ou a faixa de cifras.
   As duas filas de links de texto de hoje desaparecem: a navegação vai para a barra
   de abas inferior. O H1 da tela sai das views e passa a ser um `content_for :page_title`
   renderizado pelo header, para não haver dois títulos.

4. **Barra de abas inferior.** Novo partial `app/views/shared/_tab_bar.html.erb`:
   grid de 4 colunas, `bg-surface border-t border-line`, ícone Lucide 21px + rótulo
   `700 10px`; ativo em `text-brand`, inativo em `#67718a`. Abas do cliente:
   Buscar (`providers_path`), Mis citas (`appointments_path`), Mensajes (placeholder),
   Perfil (`edit_user_registration_path`). Abas do provedor: Agenda (`dashboard_path`),
   Citas, Clientes (placeholder), Perfil. Marcar a ativa por `controller_name`.

5. **Citas (`appointments/index` + `_card`).** O cartão arredondado atual vira uma
   **linha** dentro de um bloco branco único (`rounded-[8px] border border-line
   overflow-hidden`), cada linha com `border-b border-line-2`:
   - coluna esquerda 66px, `bg-surface-2 border-r border-line-2`, centralizada:
     dia (`800 22px`), mês (`700 10px` uppercase `text-ink-3`), hora (`800 12px text-brand`);
   - à direita: nome (`800 15px`), serviço (`400 13px text-ink-2`), etiqueta de status
     no canto superior direito;
   - aviso de pagamento pendente: bloco com `border-l-[3px] border-[#d97706] bg-[#fdf4e5]`;
   - ações em linha, alinhadas à esquerda: **Ver cita** sólido azul, **Reprogramar**
     contornado, **Cancelar** só texto vermelho — todas com `rounded-[6px]`.
   As duas seções («Mis citas» / «Citas de mis clientes») continuam como hoje; as abas
   **Próximas / Pasadas** do protótipo são um filtro novo (ver «Fora de escopo»).

6. **Mi Agenda (`dashboard/show` + `_calendar` + `_day_agenda`).**
   - As cifras do topo (`Ingresos del mes` com o toggle `reveal` já existente e
     `Citas hoy`) ficam **dentro** do cabeçalho azul, separadas por
     `border-t`/`border-r` em `rgba(255,255,255,.28)`; a cifra de citas em `#6ee89b`.
   - O calendário passa a grade **a linha**: bloco branco com cabeçalho de navegação
     (mês + dois botões contornados 30x30 `rounded-[6px]`), faixa de dias da semana
     em `bg-surface-2` uppercase `700 10px`, e células de 44px **sem raio**,
     separadas por `border-r`/`border-b` em `#d8dce5`. Dia selecionado: `bg-brand text-white`.
     Marcador de dia com citas: barra de 6x3px em `#157f3c` (branca quando o dia está selecionado).
     Manter os `link_to` com `data: { turbo_frame: "dashboard_panel" }` como estão hoje.
   - A agenda do dia usa as mesmas linhas de `Citas`, com a coluna esquerda mostrando
     só a hora e as ações **Confirmar** (verde sólido) + **Reprogramar** (contornado).
   - «Bloquear: Hoy | Período» vira uma faixa no pé do bloco branco, com os dois
     botões contornados — mantendo os `button_to` e o `modal_controller` atuais.
   - Data do dia: `Domingo, 13 de septiembre` — capitalizar **apenas** a primeira
     letra (não usar `capitalize` do CSS, que erra o «de» e o mês).

7. **Proveedores (`providers/index`).** Cabeçalho azul com busca e chips de categoria
   dentro dele; a lista vira cartões brancos `rounded-[8px] border border-line p-[10px]`,
   com foto 96x96 `rounded-[6px]` à esquerda, nome, categoria, linha de avaliação
   (estrela `#f5a524`), distância, pílula «Disponible hoy» em verde e botão
   **Ver horarios** sólido azul `rounded-[6px]`. A foto usa `provider_profile.logo`
   quando existir; quando não, o avatar de categoria atual (`shared/_category_avatar`)
   no mesmo tamanho e raio.

8. **Ícones.** Lucide (24px, `stroke-width:2`, `stroke-linecap/linejoin:round`). Os
   paths já usados no app são os mesmos do protótipo; os novos (abas, estrela, filtro,
   coração) estão nos arquivos HTML deste pacote — copiar de lá.

## Interações e comportamento

- **Seleção de dia no calendário**: já existe via Turbo Frame `dashboard_panel`
  (`dashboard_path(date:)`). Nada novo.
- **Navegação de mês**: idem, `date: (calendar_month ± 1.month)`.
- **Toggle de ingressos**: `reveal_controller.js` existente; no tema azul o ícone fica
  em `rgba(255,255,255,.8)`.
- **Abas Próximas/Pasadas** (tela Citas): filtro por `scheduled_at` — no protótipo é
  estado local; no app, um parâmetro na URL (`?scope=past`) com Turbo, para manter
  o botão «voltar» funcionando.
- **Hovers**: botão sólido azul → `#0b2f87`; sólido verde → `#0f6530`; contornado →
  fundo `#eef1f6`; «Cancelar» → fundo `#fbeceb`. Foco visível: anel de 2px em `#1546c6`,
  `outline-offset: 2px` (não deixar o azul padrão do navegador).
- **Alvos de toque**: mínimo 44px de altura em botões e células de calendário.

## Estado

Nada de novo no servidor além do filtro `scope` da tela Citas. O restante do estado
continua em Turbo Frames + Stimulus como hoje (`modal`, `reveal`, `booking`,
`weekly_schedule`, `toast`).

## Assets

- **Fonte**: Archivo (Google Fonts).
- **Mascote Dino**: **não está incluído**. Nos protótipos aparece como um espaço
  hachurado de 40–44px com o rótulo `DINO`, no canto esquerdo do cabeçalho. É preciso
  fornecer a arte (SVG de preferência, versão para fundo azul) e trocar o placeholder.
- **Fotos de provedores**: placeholders hachurados de 96x96 com o rótulo `FOTO`. No app
  vêm de `provider_profile.logo` (Active Storage/Cloudinary) ou do avatar de categoria.
- **Ícones**: Lucide, inline no markup.

## Fora de escopo (decidir antes de implementar)

- Abas **Mensajes** e **Clientes** da barra inferior não têm tela desenhada nem rota.
- Avaliações (`4,8 (120)`) e distância (`1,2 km`) na lista de provedores não existem
  no modelo atual — hoje há `city`/`category` e geocodificação. Ou se cria o dado, ou
  essas linhas saem do card.
- Ficha pública do provedor com calendário e horários ainda não foi redesenhada.
- Versão desktop do painel (a segunda referência que você enviou) ainda não foi desenhada.

## Arquivos deste pacote

- `ElCitaDino App.dc.html` — documento de design completo. Turno 6 = **tema escolhido**
  (6a Citas, 6b Mi Agenda, 6c Buscar). Turno 5 e 4 = variações azuis anteriores.
  Turno 3 = paletas comparadas. Turno 2 = **opção Modernist em standby**.
  Turno 1 = recriação da UI atual.
- `BuscarPaleta.dc.html` — tela Buscar parametrizada por paleta/raio (usada em 3a–3d e 6c).
- `BuscarAzul.dc.html` — tela Buscar com cabeçalho azul (4a–4c).
- `support.js` — runtime necessário para abrir os arquivos `.dc.html` no navegador.

Abrir `ElCitaDino App.dc.html` em um navegador para ver todas as telas; o turno 6 é
o primeiro bloco… (os turnos estão em ordem decrescente, o mais novo no topo).
