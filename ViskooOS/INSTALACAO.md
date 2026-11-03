# ViskooOS — Personalização do Ubuntu GNOME

Pasta auto-instalável para deixar um **Ubuntu recém-instalado** com o visual ViskooOS: tema escuro estilo macOS, cursor Bibata, wallpaper próprio, tema do painel (GNOME Shell) e **logo ViskooOS na tela de boot**. Tudo pode ser desfeito com `uninstall.sh`.

> Testado como referência em: **Ubuntu 26.10 · GNOME Shell 51 · Wayland**.

---

> Histórico de mudanças: veja [`ATUALIZACOES.md`](ATUALIZACOES.md).

## 1. Conteúdo da pasta

```
ViskooOS/
├── INSTALACAO.md          ← este guia
├── install.sh             ← instalador automático
├── uninstall.sh           ← desfaz tudo e volta como era antes
└── ViskooOS/
    ├── wallpapers/          12 wallpapers (padrão: motocicleta-custom-em-garagem-industrial.png)
    ├── passos-de-instalacao-viskooos.docx   (guia antigo)
    ├── plymouth/            tela de boot estilo Apple (logo, barra de progresso, script, preview.png)
    ├── branding/            logos ViskooOS que substituem os do Ubuntu no sistema (gerados pelo build.py)
    ├── shell-gnome-dark-mode/   logos "distributor" do painel → vão no tema de Shell "Dark-Mode"
    ├── _.themes/   → ~/.themes  (temas GTK e de Shell)
    └── _.icons/    → ~/.icons   (ícones e cursores)
```

### O que é cada item

| Pasta | Tipo | Destino |
|---|---|---|
| `_.themes/ViskooOS` | **Kit ViskooOS** — GTK 3/4 (Aplicativos legados) + GNOME Shell, modo escuro com detalhes laranja | `~/.themes` |
| `_.icons/ViskooOS` | **Kit ViskooOS** — ícones (Adwaita com pastas laranja, logo ViskooOS no botão de aplicativos do dock) + **cursor** DMZ preto com contorno laranja | `~/.icons` |
| `viskooos-kit/build.py` | Gerador do kit (para mudar o tom de laranja ou refazer o kit) | — |
| `_.themes/macOS-Dark-master` | Tema GTK 2/3 + GNOME Shell (o mais completo) | `~/.themes` |
| `_.themes/Dark-Mode` | Tema do **GNOME Shell** (painel/menus) | `~/.themes` |
| `_.themes/Carapace-Graphite` | Tema do GNOME Shell | `~/.themes` |
| `_.themes/deepin-dark`, `Plastik-Dark`, `Plastik-Griss`, `Gn-OSX-HSierra-1.2.1-S`, `McOS-MJV-Dark-mode-1.1` | Temas GTK | `~/.themes` |
| `_.themes/dolphin` | **Ícones** "La Capitaine" (estava na pasta errada) | `~/.icons/La-Capitaine` |
| `_.themes/KvGlow-MojaveDark`, `Mojave-dark` | Temas **Kvantum** (apps Qt/KDE) | `~/.config/Kvantum` |
| `_.themes/macOS-Black-Transparency` | Tema do dock **Plank** | `~/.local/share/plank/themes` |
| `_.icons/BibataMOD` | **Cursor** Bibata Oil | `~/.icons` |
| `_.icons/default` | Define BibataMOD como cursor padrão | `~/.icons` |
| `_.icons/OSX-ElCap` | Cursor estilo macOS | `~/.icons` |
| `_.icons/macOS`, `Macos-sierra-CT-0.8.1`, `Matte-Icons`, `OSX-Impression` | Pacotes de ícones | `~/.icons` |
| `shell-gnome-dark-mode/*.svg` | Logos do botão "Atividades" | `~/.themes/Dark-Mode/gnome-shell/assets/` |
| `wallpapers/*` | 12 papéis de parede (aparecem em Configurações → Aparência). Padrão: **Motocicleta Custom em Garagem Industrial** | `~/.local/share/backgrounds/viskooos` |
| `plymouth/` | Tela de boot minimalista estilo Apple: logo no centro + barra de progresso fina | `/usr/share/plymouth/themes/viskooos` |

---

### Nomes de arquivos

Todos os arquivos e pastas usados pelo instalador têm nomes **sem espaços e sem acentos** (ex.: `Liberdade na Estrada ao Pôr do Sol.png` → `liberdade-na-estrada-ao-por-do-sol.png`). **Wallpapers novos:** é só colocar a imagem (`.png`, `.jpg`, `.jpeg` ou `.webp`) em `ViskooOS/wallpapers/` com qualquer nome — o instalador padroniza o nome sozinho na hora de copiar. Também dá para usar o nome original em `WALLPAPER="Minha Foto Nova.jpg"`.

**Temas novos:** use nomes sem espaços e sem acentos (ex.: `Meu-Tema`), pois o nome da pasta é o nome do tema.

---

## 1b. Kit ViskooOS (modo escuro + laranja)

Aparece com o nome **ViskooOS** no **Ajustes → Aparência** em *Cursor*, *Ícones*, *Shell* e *Aplicativos legados*. Foi feito a partir das bases preferidas (**Yaru-dark** para os apps e também para o **Shell** — painel, menus, dock e login —, ícones Adwaita e cursor DMZ-Black), com o **laranja `#ea7320`** fixo no lugar da cor de destaque do sistema e fundos escurecidos. O Shell é uma cópia do `/usr/share/gnome-shell/theme/Yaru-dark` gerada pelo `build.py`.

- **Dock:** cantos arredondados (o tema antigo deixava quadrado) e **logo ViskooOS** no botão *Mostrar aplicativos*, sempre em **primeiro lugar** no dock (em tamanho menor, 60% do ícone — ajuste `DOCK_LOGO_SCALE` no `build.py`).
- **Logo do Ubuntu → ViskooOS em todo lugar:** *Configurações → Sobre* (logo + nome "ViskooOS"), ícones `ubuntu-logo*`, `distributor-logo` e `start-here`, os logos em `/usr/share/pixmaps` e o tema de boot reserva do Ubuntu (spinner/bgrt). Os arquivos do sistema são trocados com `dpkg-divert` (o original fica como `*.ubuntu` e atualizações do Ubuntu não trazem o logo de volta).
- **Painel superior, menus e calendário:** visual do Yaru-dark, com destaques em laranja ViskooOS.
- **Campos de texto do GNOME** (busca, senha, login, diálogos) e menus **arredondados**, com borda laranja ao focar.
- **Apps modernos** (Configurações, Arquivos…) recebem as cores via `~/.config/gtk-4.0/gtk.css` (o original é guardado e volta no `uninstall.sh`).

Para mudar o laranja: edite `ACCENT_HUE`/`ACCENT` em `ViskooOS/viskooos-kit/build.py`, rode `python3 -I ViskooOS/viskooos-kit/build.py` (ou só `... build.py icons branding` para refazer ícones/logos) e depois `SKIP_APT=1 SKIP_BOOT=1 bash install.sh`.

---

## 2. ⚠️ Problemas conhecidos (leia antes)

1. **Os pacotes de ícones estão incompletos.** Existem ~300 pastas vazias: `macOS`, `Matte-Icons`, `Macos-sierra-CT`, `OSX-Impression` e `La Capitaine` têm só o `index.theme`, sem os ícones. Provavelmente os arquivos se perderam ao copiar/compactar (pacotes de ícones usam muitos *symlinks*). Por isso o padrão agora é o kit **ViskooOS** (herda os ícones Adwaita do sistema, que estão completos).
   **Solução:** baixar de novo o pacote original (ex.: *La Capitaine* no GitHub, ou *WhiteSur icon theme*) e substituir a pasta.
2. **O tema de Shell "Dark-Mode" está sem a pasta `assets`** (só tem o `gnome-shell.css`). O instalador copia os logos de `shell-gnome-dark-mode`, mas outros ícones (checkbox, switches, calendário) podem aparecer sem imagem. O `Carapace-Graphite` também só tem o CSS.
3. **Os temas são de ~2018 (GNOME 3.x).** No GNOME 51:
   - Apps modernos (libadwaita: Configurações, Arquivos, Texto…) **ignoram o tema GTK** — só respeitam claro/escuro.
   - Apps GTK3 antigos e o Ajustes aplicam o tema normalmente.
   - Temas de Shell antigos podem ter partes desalinhadas.
4. **Plank não funciona bem no Wayland.** O tema do dock é copiado, mas o Ubuntu já usa o Ubuntu Dock.

> Alternativa moderna recomendada (mesmo visual macOS, compatível com GNOME atual): **WhiteSur GTK + WhiteSur icons + Bibata cursor**. A IA pode instalar isso também, se você pedir.

---

## 3. Instalação automática (recomendado)

Em um Ubuntu recém-instalado, copie a pasta `ViskooOS` para qualquer lugar (ex.: `~/Documentos/ViskooOS`) e rode:

```bash
cd ~/Documentos/ViskooOS
bash install.sh
```

Depois **faça logout e login** (necessário no Wayland para o tema do Shell e o cursor).

### O que o script faz

1. `apt install` de: `gnome-tweaks`, `gnome-shell-extension-manager`, `gnome-shell-extensions` (contém o *User Themes*) e `qt-style-kvantum`.
2. Cria `~/.themes`, `~/.icons`, `~/.config/Kvantum`, etc.
3. Copia cada tema/ícone para o destino certo (tabela acima).
4. Instala os wallpapers (visíveis em Configurações → Aparência) e aplica o padrão **Motocicleta Custom em Garagem Industrial** na área de trabalho e na tela de bloqueio.
5. Ativa modo escuro + destaque laranja e o kit **ViskooOS** (GTK, Shell, ícones, cursor e apps modernos), com os botões **fechar, minimizar e maximizar alinhados à esquerda** e com fundos nas cores do macOS (vermelho `#ff5f57`, amarelo `#febc2e`, verde `#28c840`; ajuste `BTN_CLOSE`/`BTN_MIN`/`BTN_MAX` no `build.py`).
6. Configura o **dock**: embaixo, flutuante com cantos arredondados, auto-ocultar, ícones de 56 px e logo ViskooOS no botão de aplicativos, **em primeiro lugar** no dock (`show-apps-at-top`).
7. Ativa a extensão **User Themes** e define o tema do Shell.
8. Troca os logos do Ubuntu do sistema pelo logo ViskooOS (`dpkg-divert`, reversível).
9. Instala o tema de boot **ViskooOS** (Plymouth) e recria o initramfs.
10. Antes de tudo, **salva suas configurações atuais** em `~/.local/share/viskooos/` (para o `uninstall.sh`).

### Escolhendo outros temas

```bash
GTK_THEME="Plastik-Dark" SHELL_THEME="Carapace-Graphite" CURSOR_THEME="OSX-ElCap" bash install.sh
SKIP_APT=1 bash install.sh      # pula o apt (só copia e aplica)
SKIP_BOOT=1 bash install.sh     # não mexe na tela de boot
SKIP_BRANDING=1 bash install.sh # não troca os logos do Ubuntu em /usr/share
WALLPAPER=motociclista-cyberpunk-na-chuva-neon.png bash install.sh   # outro wallpaper padrão
```

Padrões: `GTK_THEME=ViskooOS`, `SHELL_THEME=ViskooOS`, `ICON_THEME=ViskooOS`, `CURSOR_THEME=ViskooOS`, `ACCENT_COLOR=orange`, `WALLPAPER=motocicleta-custom-em-garagem-industrial.png`.

---

## 4. Instalação manual (passo a passo)

```bash
# 1. Pacotes
sudo apt update
sudo apt install -y gnome-tweaks gnome-shell-extension-manager gnome-shell-extensions qt-style-kvantum

# 2. Pastas
mkdir -p ~/.themes ~/.icons ~/.config/Kvantum ~/.local/share/backgrounds

# 3. Copiar (a partir da pasta ViskooOS/ViskooOS)
cd ViskooOS
cp -a _.themes/* ~/.themes/
cp -a _.icons/.  ~/.icons/
mv ~/.themes/dolphin ~/.icons/La-Capitaine
mv ~/.themes/KvGlow-MojaveDark ~/.themes/Mojave-dark ~/.config/Kvantum/
mkdir -p ~/.themes/Dark-Mode/gnome-shell/assets ~/.local/share/backgrounds/viskooos
cp shell-gnome-dark-mode/*.svg ~/.themes/Dark-Mode/gnome-shell/assets/
cp wallpapers/*.png ~/.local/share/backgrounds/viskooos/
```

4. **Ativar User Themes:** abra **Gerenciador de Extensões** → aba *Instalado* → ative **User Themes** (se não aparecer, aba *Navegar* → pesquise "User Themes" → instalar). Faça logout/login.
5. **Aplicar:** abra **Ajustes** (`gnome-tweaks`) → *Aparência*:
   - Cursor: `ViskooOS`
   - Ícones: `ViskooOS`
   - Shell: `ViskooOS`
   - Aplicativos legados: `ViskooOS`
   - Apps modernos (libadwaita): `cp ViskooOS/_.themes/ViskooOS/gtk-4.0/libadwaita.css ~/.config/gtk-4.0/gtk.css` e, em Configurações → Aparência, cor de destaque **laranja**
6. **Wallpaper:** Configurações → Plano de fundo → adicionar imagem → `~/.local/share/backgrounds/viskooos/motocicleta-custom-em-garagem-industrial.png`.
7. **Apps Qt (opcional):** abra o *Kvantum Manager* → selecione `KvGlow-MojaveDark`.

---

### Tela de boot (Plymouth) — estilo Apple

Fundo preto, **logo ViskooOS branco no centro exato da tela** e uma **barra de progresso fina e arredondada** logo abaixo do logo, que enche suavemente (sem saltos). O logo aparece com fade-in. Ao desligar/reiniciar aparece só o logo, como no Mac. Se o disco for criptografado, o campo de senha aparece no lugar da barra. Veja `ViskooOS/plymouth/preview.png`.

Arquivos em `ViskooOS/plymouth/`:

| Arquivo | Função |
|---|---|
| `logo.png` | Logo branco, fundo transparente (240px; o script reduz para 96px, ou 192px em 4K) |
| `progress-track.png` / `progress-fill.png` | Trilho cinza e preenchimento branco da barra |
| `viskooos.script` | Lógica da animação (tamanhos e posições ficam no topo do arquivo) |
| `viskooos.plymouth` | Declaração do tema |

Instalação manual:

```bash
cd ViskooOS/plymouth
sudo mkdir -p /usr/share/plymouth/themes/viskooos
sudo install -m644 logo.png progress-track.png progress-fill.png viskooos.script viskooos.plymouth /usr/share/plymouth/themes/viskooos/
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/viskooos/viskooos.plymouth 200
sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/viskooos/viskooos.plymouth
sudo update-initramfs -u
```

Observações:
- O logo da **BIOS/UEFI** (antes do Ubuntu carregar) não pode ser trocado; o logo ViskooOS aparece logo em seguida.
- Para trocar o logo, substitua `logo.png` (PNG branco, fundo transparente, quadrado) e rode o install de novo.
- Para testar sem reiniciar: `sudo plymouthd; sudo plymouth --show-splash; sleep 8; sudo plymouth --quit`.
- O avanço da barra é uma estimativa do Plymouth baseada nos boots anteriores; ela fica mais precisa depois de 2–3 reinicializações.

## 5. Instalação usando IA (Claude Code)

Num Ubuntu novo, instale o Claude Code e peça para ele fazer tudo:

```bash
sudo apt install -y curl
curl -fsSL https://claude.ai/install.sh | bash
cd ~/Documentos/ViskooOS
claude
```

E diga, por exemplo:

> Leia o INSTALACAO.md desta pasta e instale tudo no meu Ubuntu. Verifique o resultado no final.

---

## 6. Desinstalar / voltar como era antes

```bash
cd ~/Documentos/ViskooOS
bash uninstall.sh
```

O `uninstall.sh`:
1. Restaura **exatamente** as configurações que você tinha antes (tema, ícones, cursor, wallpaper, extensões), a partir do backup salvo pelo `install.sh`. Se não houver backup, volta ao padrão do Ubuntu.
2. Apaga **só** os arquivos que o instalador criou (`~/.themes/...`, `~/.icons/...`, Kvantum, wallpaper). Pastas que já existiam ou que têm outros arquivos seus são mantidas.
3. Devolve os logos originais do Ubuntu, volta a tela de boot ao tema anterior e recria o initramfs.
4. Pergunta se quer remover os pacotes apt que **não existiam** antes da instalação (`REMOVE_APT=1` remove sem perguntar, `REMOVE_APT=0` mantém).

Depois faça **logout e login** (e reinicie para ver o boot original).

---

## 7. Verificação rápida

```bash
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface cursor-theme
gsettings get org.gnome.shell enabled-extensions
gnome-extensions info user-theme@gnome-shell-extensions.gcampax.github.com
update-alternatives --query default.plymouth | grep Value   # tema de boot ativo
```

---

## Instalador de aplicativos (ViskooOS Apps)

Escolha numa lista os apps que quer e ele instala tudo sozinho. Cada app tem **várias fontes em ordem de preferência** (quase sempre **Flatpak/Flathub** primeiro, depois APT do Ubuntu e Snap; .deb oficial quando é o melhor caminho, como Chrome e VS Code). Depois de cada tentativa ele **confere se o app ficou instalado**; se não ficou, tenta a próxima fonte. Cada app roda **isolado, num processo próprio**: se der erro, travar ou passar do tempo, só ele para (o dpkg é recuperado sozinho) e a fila segue com os próximos.

Antes dos apps, o passo **Preparando o sistema** pausa o PackageKit durante a instalação (ele pegava a trava do APT e dava `Não foi possível obter a trava /var/lib/apt/lists/lock`), espera outros instaladores terminarem, conserta instalações interrompidas (`dpkg --configure -a`) e instala o `curl` se faltar.

```bash
bash install-apps.sh            # janela escura com abas Sistema / Apps (viskooos-apps.py, GTK4)
bash install-apps.sh --zenity   # janela simples antiga (zenity)
bash install-apps.sh --tui      # menu no terminal (ESPAÇO marca, ENTER confirma)
bash install-apps.sh --dry-run  # simula (com barras de progresso), sem instalar nada
bash install-apps.sh --list     # mostra o catálogo e o que já está instalado
```

- Depois da 1ª execução aparece **ViskooOS Apps** no menu de aplicativos.
- **Aba Sistema:** *Atualizar o sistema* e *Flatpak + Flathub* vêm marcados; *Reparar pacotes* e *App Center* ficam opcionais.
- **Aba Apps:** nada vem marcado. Tem busca (🔍 ou só começar a digitar), filtro por categoria e botão *Marcar todos* por categoria. Os apps já instalados mostram o próprio ícone.
- **Tela de instalação:** barra do app atual com a porcentagem real (download e instalação de APT, Flatpak, Snap e .deb), barra geral, fila com o status de cada app, botões **Pular este app** e **Cancelar o restante**. No fim: **Tentar de novo as que falharam**, e um botão em cada item com problema mostra o que aconteceu.
- **ArtCraft** (getartcraft.com/apps): Launcher, PhotoCraft, VectorCraft, FilmCraft, LightCraft, PdfCraft, EffectCraft, DesignCraft, FigCraft, WordCraft, SoundCraft, DeckCraft, CADCraft e GridCraft, instalados pelo repositório APT oficial `https://getartcraft.com/apt` (os .deb vêm das GitHub Releases da ArtCraft) e, como reserva, pelo Flatpak `artcraft-oci` (em 03/11/2026 o índice Flatpak deles respondia erro 503). **Atenção:** o repositório APT da ArtCraft ainda **não é assinado** (`trusted=yes`), então o APT não consegue verificar a origem dos pacotes.
- **AnyDesk** vem do repositório APT oficial (deb.anydesk.com); **LibreOffice** via APT com idioma pt-BR; **FileZilla** via Flathub.
- A senha é pedida **uma vez** (janela do sistema). Apps já instalados aparecem como *✔ instalado* e vêm desmarcados.
- **Efeitos Compiz:** *Compiz Liquid* (janelas gelatinosas) e *Compiz Magic Lamp* (minimizar estilo lâmpada) são extensões do GNOME. O instalador pede ao próprio GNOME Shell para instalar: aparece uma confirmação do GNOME e o efeito **ativa na hora**, sem sair da sessão. Se a confirmação for recusada, instala pelo .zip, e aí ativa depois de sair e entrar na sessão. *Gerenciador de Extensões* e *Ajustes do GNOME* também estão na categoria Efeitos, para ajustar a intensidade.
- Substituições: Atom → **VS Code** (Atom foi descontinuado), PlayOnLinux → **Bottles**; Pitivi e FileZilla vêm do Flathub. Pingendo não existe mais.
- Log: `~/.local/share/viskooos/install-apps.log` (mostra cada fonte tentada e por qual o app foi instalado). A parte root também grava em `/var/log/viskooos-apps.log`, então a instalação continua registrada mesmo se a janela for fechada.
- Para mudar a ordem das fontes de um app, edite a última coluna do `CATALOG` (ex.: `flatpak:org.videolan.VLC apt:vlc snap:vlc`).
- Para incluir/remover apps ou mudar os que vêm marcados, edite o bloco `CATALOG` no início do `install-apps.sh` (coluna 2: `1` = marcado por padrão; categoria `Sistema` vai para a aba Sistema, as outras para a aba Apps).
