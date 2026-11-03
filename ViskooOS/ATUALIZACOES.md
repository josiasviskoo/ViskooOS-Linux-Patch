# ViskooOS — Atualizações

## 2026-11-03

- **Boot → login sem "pulo" para a direita (2 monitores).** O GDM não conhecia o arranjo das telas
  (ultrawide à esquerda + notebook à direita) e reorganizava os monitores ao assumir a tela, deslocando o
  último quadro do boot. O `install.sh` (passo 9b) agora copia o `~/.config/monitors.xml` para a tela de login;
  o `uninstall.sh` desfaz.
- **Sombra das janelas estilo macOS:** mais intensa, mais difusa e um pouco mais afastada (deslocada para baixo);
  mais suave nas janelas em segundo plano. Vale para apps GTK3, GTK4 e libadwaita.
- **Fontes do sistema = fontes do site viskoo.com.br:** **DM Sans** (interface, documentos, títulos) e
  **DM Mono** (terminal/código), com todas as variações (Thin a Black, itálicos). Ficam em
  `ViskooOS/fonts/` (licença OFL) e são aplicadas pelo passo 7b2 do `install.sh`; o `uninstall.sh` volta as originais.

- **ViskooOS Apps: instalador reescrito (mais robusto e com progresso real).**
  - **Compiz não instalava:** o download das extensões usava o `curl`, que não estava instalado
    (`curl: comando não encontrado`). Agora o download é feito pelo Python (sem depender do curl) e o
    preparo do sistema instala o curl se faltar. As duas extensões têm versão para o GNOME 51.
    Elas são instaladas pelo próprio GNOME Shell e **ativam na hora**, sem logout (com o .zip como reserva).
  - **Travas do APT:** o PackageKit pegava a trava no meio (`trava /var/lib/apt/lists/lock … packagekitd`).
    Agora ele fica pausado durante a instalação (`systemctl mask --runtime`, desfeito ao terminar), o instalador
    espera outros instaladores liberarem o APT e tenta de novo se a trava for pega no meio.
  - **Instalações interrompidas** (ex.: reiniciar no meio) são consertadas no início (`dpkg --configure -a`).
  - **Cada app isolado:** cada um roda no seu processo, com limite de tempo. Se der erro ou travar, só ele para
    (com recuperação do dpkg) e os próximos continuam. A interface pode **pular** o app atual ou **cancelar** o resto.
  - **Barra de progresso real:** APT (`APT::Status-Fd`), Flatpak, Snap e downloads `.deb` rodam num pseudo-terminal
    e a porcentagem vai para a interface. Antes, o Flatpak não mostrava nada e parecia travado.
  - **Interface nova** (`viskooos-apps.py`): ícones reais dos apps, filtro por categoria, card de progresso com o app atual
    e a barra geral, fila com status por item, "ver o que aconteceu" em cada falha, "tentar de novo as que falharam",
    confirmação ao fechar durante a instalação. Modos zenity/terminal também ganharam a barra.
  - Novos itens em **Efeitos**: *Gerenciador de Extensões* e *Ajustes do GNOME*.
  - Versões anteriores guardadas em `_tmp/install-apps.sh.bak3` e `_tmp/viskooos-apps.py.bak`.

- **Dock:** logo ViskooOS (botão *Mostrar aplicativos*) em **primeiro lugar** no dock
  (`install.sh` → `DOCK[show-apps-at-top]=true`).
- **Botões da janela à esquerda:** fechar, minimizar e maximizar alinhados à esquerda, estilo macOS
  (`install.sh` → `BUTTON_LAYOUT="close,minimize,maximize:"`; guardado no backup e restaurado pelo `uninstall.sh`).
- **Cores do macOS nos botões da janela:** fundos vermelho `#ff5f57` (fechar), amarelo `#febc2e` (minimizar)
  e verde `#28c840` (maximizar), em **bolinhas** com o ícone no centro.
  - `ViskooOS/viskooos-kit/build.py` → `BTN_CLOSE`, `BTN_MIN`, `BTN_MAX` e `titlebutton_css()`.
  - Já aplicado em `ViskooOS/_.themes/ViskooOS/gtk-3.0`, `gtk-4.0` (`gtk.css`, `gtk-dark.css`) e `gtk-4.0/libadwaita.css`.
  - Não afeta apps com barra de título própria (ex.: Chrome) nem janelas decoradas pelo próprio GNOME.
- **Tela de boot (Plymouth):** logo ViskooOS agora **sempre no centro exato** da tela e a barra de loading
  na **parte de baixo** (140 px acima da borda inferior, escalado em telas HiDPI).
  - Causa do logo fora do centro: as posições eram calculadas uma única vez, na resolução do firmware;
    quando o driver de vídeo assume a resolução nativa, o logo ficava nas coordenadas antigas.
    Agora `layout()` recalcula tudo sempre que a resolução muda.
  - `ViskooOS/plymouth/viskooos.script` e `preview.png`. Aplicado pelo passo 9 do `install.sh` (requer `update-initramfs`).
- **Zen Browser no ViskooOS Apps** (aba Apps → Internet), instalado via Flatpak `app.zen_browser.zen`, já com o design ViskooOS:
  - Interface **cinza chumbo** (`#1c1c1e`, tons do modo escuro do macOS), sem gradiente/granulação; as páginas dos sites não são alteradas.
  - **Barra de endereços fixa no topo**; só a barra lateral de abas se esconde (aparece ao encostar o mouse na borda esquerda). Ctrl+Alt+C liga/desliga.
  - Arquivos: `ViskooOS/zen/userChrome.css`, `ViskooOS/zen/user.js` (bloco `// >>> ViskooOS >>>`, preserva o resto do user.js)
    e `ViskooOS/zen/apply-zen-theme.sh` (aplica em todos os perfis; cria o perfil se o Zen nunca foi aberto).
  - Novo mecanismo no `install-apps.sh`: funções `user_post_<id>` rodam **como o usuário** depois da parte root
    (modo `--post-user`, chamado pela interface `viskooos-apps.py` e pelo fluxo zenity/terminal).
  - Favoritos **não** fazem parte do ViskooOS: ficam na conta Mozilla do usuário (Sincronização do Zen), quando ele quiser.
- **Zen:** campo de endereço com cantos **100% arredondados** (pílula); com as sugestões abertas vira painel com cantos de 20px.
  (`ViskooOS/zen/userChrome.css`)
