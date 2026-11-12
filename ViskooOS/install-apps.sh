#!/usr/bin/env bash
# ViskooOS Apps — instalador de aplicativos para Ubuntu (com interface gráfica)
#
# Uso:
#   bash install-apps.sh            interface gráfica (GTK4/libadwaita, viskooos-apps.py)
#   bash install-apps.sh --zenity   interface simples (zenity)
#   bash install-apps.sh --tui      menu no terminal (whiptail)
#   bash install-apps.sh --dry-run  simula tudo (com barras de progresso falsas), sem instalar nada
#   bash install-apps.sh --list     lista o catálogo e o que já está instalado
#
# Pede a senha UMA vez. Log em ~/.local/share/viskooos/install-apps.log (e /var/log/viskooos-apps.log)
# Para adicionar/remover apps do menu, edite o CATÁLOGO abaixo.
#
# Como funciona (resumo):
#   • Antes de tudo, "Preparando o sistema": pausa o PackageKit (ele travava o APT), espera outros
#     instaladores terminarem, conserta instalações interrompidas (dpkg --configure -a) e garante curl.
#   • Cada app roda ISOLADO, num processo próprio: se der erro, travar ou estourar o tempo, só ele
#     para (e o dpkg é recuperado); a fila segue com os próximos. A interface pode pular um app.
#   • Cada app tenta suas fontes em ordem (ex.: Flatpak → APT → Snap) e CONFERE se ficou instalado.
#   • O progresso real (APT, Flatpak, Snap, downloads) vira marcadores @@PROG para a barra.
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(dirname "$SELF")"
TITLE="ViskooOS Apps"
# depois do DesViskar-OS.sh: sem o nome e o logo ViskooOS
[ -f "$HOME/.local/share/viskooos/sem-marca" ] && TITLE="Instalar Apps"

# ──────────────────────────────── CATÁLOGO ────────────────────────────────
# id | marcado por padrão (1/0) | categoria | nome | descrição | fontes
# "fontes" = lista separada por espaço, tentada EM ORDEM até uma funcionar e o app aparecer instalado:
#   flatpak:<id Flathub>      apt:<pacote>[,<pacote>...]   snap:<nome> (tenta normal e --classic)
#   deb:<pacote>=<URL .deb>   acapt:<pacote> (repositório APT da ArtCraft, getartcraft.com/apt)
#   acflat:<id> (Flatpak OCI da ArtCraft)   ext:<UUID extensions.gnome.org>   fn:<função do_*>
# Categoria "Sistema" vai para a aba Sistema da interface; as demais, para a aba Apps.
CATALOG='
update|1|Sistema|Atualizar o sistema|apt upgrade, snap refresh e flatpak update antes de instalar|fn:update
flatpak|1|Sistema|Flatpak + Flathub|Suporte a apps Flatpak (fonte principal dos apps abaixo)|fn:flatpak
repair|0|Sistema|Reparar pacotes|dpkg --configure -a, apt -f install, limpa cache|fn:repair
snap-store|0|Sistema|App Center (Snap Store)|Loja de aplicativos do Ubuntu|snap:snap-store
ext-manager|0|Efeitos|Gerenciador de Extensões|Liga, desliga e configura os efeitos Compiz e outras extensões|apt:gnome-shell-extension-manager flatpak:com.mattjakeman.ExtensionManager
tweaks|0|Efeitos|Ajustes do GNOME|Fontes, temas, botões da janela e animações (GNOME Tweaks)|apt:gnome-tweaks
compiz-liquid|0|Efeitos|Compiz Liquid|Janelas gelatinosas (wobbly) ao mover e redimensionar|ext:compiz-windows-effect@hermes83.github.com
compiz-lamp|0|Efeitos|Compiz Magic Lamp|Minimizar com efeito de lâmpada mágica|ext:compiz-alike-magic-lamp-effect@hermes83.github.com
spotify|0|Multimídia|Spotify|Streaming de música|flatpak:com.spotify.Client snap:spotify
vlc|0|Multimídia|VLC|Player de vídeo e áudio|flatpak:org.videolan.VLC apt:vlc snap:vlc
kdenlive|0|Multimídia|Kdenlive|Editor de vídeo|flatpak:org.kde.kdenlive apt:kdenlive snap:kdenlive
pitivi|0|Multimídia|Pitivi|Editor de vídeo simples|flatpak:org.pitivi.Pitivi apt:pitivi
obs|0|Multimídia|OBS Studio|Gravação de tela e live|flatpak:com.obsproject.Studio apt:obs-studio snap:obs-studio
inkscape|0|Design|Inkscape|Editor vetorial|flatpak:org.inkscape.Inkscape apt:inkscape snap:inkscape
gimp|0|Design|GIMP|Editor de imagens|flatpak:org.gimp.GIMP apt:gimp snap:gimp
krita|0|Design|Krita|Pintura digital|flatpak:org.kde.krita apt:krita snap:krita
blender|0|Design|Blender|Modelagem e animação 3D|flatpak:org.blender.Blender snap:blender apt:blender
vectr|0|Design|Vectr|Editor vetorial (só existe como snap antigo, sem atualizações)|snap:vectr
pinta|0|Design|Pinta|Editor de imagens leve (estilo Paint.NET)|flatpak:com.github.PintaProject.Pinta apt:pinta snap:pinta
ac-launcher|0|ArtCraft|ArtCraft Launcher|Instala e atualiza todos os apps ArtCraft|acapt:artcraft-launcher acflat:ai.storyteller.artcraft-launcher
ac-photocraft|0|ArtCraft|PhotoCraft|Editor de imagens (alfa)|acapt:photocraft acflat:ai.storyteller.photocraft
ac-vectorcraft|0|ArtCraft|VectorCraft|Ilustração vetorial|acapt:vectorcraft acflat:ai.storyteller.vectorcraft
ac-filmcraft|0|ArtCraft|FilmCraft|Editor de vídeo|acapt:filmcraft acflat:ai.storyteller.filmcraft
ac-lightcraft|0|ArtCraft|LightCraft|Biblioteca de fotos e revelação RAW|acapt:lightcraft acflat:ai.storyteller.lightcraft
ac-pdfcraft|0|ArtCraft|PdfCraft|Ler, organizar, juntar, dividir e proteger PDFs|acapt:pdfcraft acflat:ai.storyteller.pdfcraft
ac-effectcraft|0|ArtCraft|EffectCraft|Motion graphics e efeitos visuais|acapt:effectcraft acflat:ai.storyteller.effectcraft
ac-designcraft|0|ArtCraft|DesignCraft|Diagramação e publicação|acapt:designcraft acflat:ai.storyteller.designcraft
ac-figcraft|0|ArtCraft|FigCraft|Design de interfaces e protótipos|acapt:figcraft acflat:ai.storyteller.figcraft
ac-wordcraft|0|ArtCraft|WordCraft|Processador de texto|acapt:wordcraft acflat:ai.storyteller.wordcraft
ac-soundcraft|0|ArtCraft|SoundCraft|Gravação, edição e mixagem de áudio|acapt:soundcraft acflat:ai.storyteller.soundcraft
ac-deckcraft|0|ArtCraft|DeckCraft|Apresentações de slides|acapt:deckcraft acflat:ai.storyteller.deckcraft
ac-cadcraft|0|ArtCraft|CADCraft|Desenho técnico e CAD|acapt:cadcraft acflat:ai.storyteller.cadcraft
ac-gridcraft|0|ArtCraft|GridCraft|Planilhas e análise de dados|acapt:gridcraft acflat:ai.storyteller.gridcraft
libreoffice|0|Escritório|LibreOffice|Suíte de escritório completa (em português)|apt:libreoffice,libreoffice-l10n-pt-br,libreoffice-help-pt-br flatpak:org.libreoffice.LibreOffice snap:libreoffice
mailspring|0|Escritório|Mailspring|Cliente de e-mail|flatpak:com.getmailspring.Mailspring snap:mailspring
slack|0|Comunicação|Slack|Chat de equipes|flatpak:com.slack.Slack snap:slack
discord|0|Comunicação|Discord|Chat de voz e texto|flatpak:com.discordapp.Discord snap:discord
telegram|0|Comunicação|Telegram|Mensageiro|flatpak:org.telegram.desktop apt:telegram-desktop snap:telegram-desktop
zen|0|Internet|Zen Browser|Navegador minimalista (motor do Firefox) com o design ViskooOS: cinza chumbo e barra de endereços no topo|flatpak:app.zen_browser.zen
chrome|0|Internet|Google Chrome|Navegador do Google|deb:google-chrome-stable=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb flatpak:com.google.Chrome
filezilla|0|Internet|FileZilla|Cliente FTP/SFTP|flatpak:org.filezillaproject.Filezilla apt:filezilla
vscode|0|Desenvolvimento|VS Code|Editor de código (.deb oficial da Microsoft; Flatpak como reserva)|deb:code=https://update.code.visualstudio.com/latest/linux-deb-x64/stable snap:code flatpak:com.visualstudio.code
postman|0|Desenvolvimento|Postman|Testes de API|flatpak:com.getpostman.Postman snap:postman
dbeaver|0|Desenvolvimento|DBeaver|Cliente de banco de dados|flatpak:io.dbeaver.DBeaverCommunity snap:dbeaver-ce
anydesk|0|Acesso remoto|AnyDesk|Acesso remoto (repositório oficial AnyDesk; Flatpak como reserva)|fn:anydesk flatpak:com.anydesk.Anydesk
teamviewer|0|Acesso remoto|TeamViewer|Acesso remoto|deb:teamviewer=https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
virtualbox|0|Utilitários|VirtualBox|Máquinas virtuais|apt:virtualbox
bottles|0|Utilitários|Bottles|Apps Windows via Wine (substitui o PlayOnLinux)|flatpak:com.usebottles.bottles
'
# ──────────────────────────────────────────────────────────────────────────

IDS=(); declare -A DEF CAT NAME DESC METH SRCS
while IFS='|' read -r id def cat name desc srcs; do
  [ -n "$id" ] || continue
  IDS+=("$id"); DEF[$id]=$def; CAT[$id]=$cat; NAME[$id]=$name; DESC[$id]=$desc; SRCS[$id]=$srcs
  first=${srcs%% *}; METH[$id]=${first%%:*}      # método principal (rótulo na interface / ext x root)
done <<< "$CATALOG"
tgt_of() { local s; for s in ${SRCS[$1]}; do [ "${s%%:*}" = "$2" ] && { echo "${s#*:}"; return; }; done; }

DRY=0
CONTROL=""          # arquivo de controle escrito pela interface: linhas "skip <id>" ou "cancel"
CUR=prep            # item em execução (para os marcadores @@PROG)
PLO=0 PHI=100       # faixa da barra do item que o próximo comando ocupa
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
APT=(apt-get -y -o DPkg::Lock::Timeout=900 -o Dpkg::Use-Pty=0 -o APT::Status-Fd=1
     -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
# Limites de tempo por comando e por app (nada pode travar a fila inteira)
T_APT=2400 T_SNAP=1500 T_FLAT=2400 T_NET=900 T_ITEM=3600

# ─────────────────────────── progresso e execução ───────────────────────────
prog() { echo "@@PROG $CUR $1	${2:-}"; }        # $1 = 0..100 (ou -1 = sem porcentagem)

# Filtra a saída de um comando: transforma progresso (APT Status-Fd, "45%", "2/9") em @@PROG
# e repassa só as linhas com texto de verdade para o log.
pf() {
  local lo=$PLO hi=$PHI line p last=-999 k n msg
  stdbuf -oL tr '\r' '\n' | sed -u 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b[()][A-Z0-9]//g; s/\x1b[=>]//g' |
  while IFS= read -r line; do
    [ -n "${line//[[:space:]]/}" ] || continue
    case "$line" in
      dlstatus:*|pmstatus:*)     # APT: "pmstatus:pacote[:arch]:45.45:Configurando x"
        [[ $line =~ ^(dl|pm)status:.*:([0-9]{1,3})(\.[0-9]+)?:(.*)$ ]] || continue
        p=${BASH_REMATCH[2]} msg=${BASH_REMATCH[4]}
        if [ "${BASH_REMATCH[1]}" = dl ]; then p=$(( lo + p * (hi - lo) * 35 / 10000 ))
        else p=$(( lo + (hi - lo) * 35 / 100 + p * (hi - lo) * 65 / 10000 )); fi ;;
      media-change*) continue ;;
      *)
        if [[ $line =~ ([0-9]{1,3})([.,][0-9]+)?[[:space:]]?% ]]; then
          p=${BASH_REMATCH[1]}; [ "$p" -gt 100 ] && p=100
          if [[ $line =~ (^|[^0-9])([0-9]{1,3})/([0-9]{1,3})([^0-9]|$) ]]; then
            k=${BASH_REMATCH[2]} n=${BASH_REMATCH[3]}
            [ "$n" -gt 0 ] && [ "$k" -ge 1 ] && [ "$k" -le "$n" ] && p=$(( ((k - 1) * 100 + p) / n ))
          fi
          p=$(( lo + p * (hi - lo) / 100 )); msg=$line
        else
          echo "$line"; continue
        fi ;;
    esac
    [ "$p" -gt "$hi" ] && p=$hi
    if [ "$p" != "$last" ]; then echo "@@PROG $CUR $p	$msg"; last=$p; fi
  done
}

# Simulação (--dry-run): mostra o comando e anima a barra
fake() { local i; for i in 20 45 70 100; do echo "@@PROG $CUR $(( PLO + i * (PHI - PLO) / 100 ))	simulando $1"; sleep 0.15; done; }

# runt <segundos> cmd...   executa com limite de tempo e progresso (124 = tempo esgotado)
runt() { local t=$1; shift; echo "\$ $*"; [ "$DRY" = 1 ] && { fake "$1"; return 0; }
  timeout --kill-after=20 "$t" "$@" < /dev/null 2>&1 | pf; local rc=${PIPESTATUS[0]}
  [ "$rc" -eq 124 ] && echo "⚠ tempo esgotado (${t}s): $1"; return "$rc"; }
# runp: igual ao runt, mas num pseudo-terminal (Flatpak/Snap/curl só mostram progresso assim)
runp() { local t=$1; shift; echo "\$ $*"; [ "$DRY" = 1 ] && { fake "$1"; return 0; }
  command -v script > /dev/null || { runt "$t" "$@"; return; }
  timeout --kill-after=20 "$t" script -qefc "stty cols 140 rows 40 2>/dev/null; exec $(printf '%q ' "$@")" /dev/null \
    < /dev/null 2>&1 | pf; local rc=${PIPESTATUS[0]}
  [ "$rc" -eq 124 ] && echo "⚠ tempo esgotado (${t}s): $1"; return "$rc"; }
run() { echo "\$ $*"; [ "$DRY" = 1 ] || "$@"; }

# ─────────────────────────────── APT seguro ───────────────────────────────
# Alguém (PackageKit, atualização automática, outro apt) está segurando as travas do APT?
apt_busy() {
  python3 -I -c '
import fcntl, sys
for f in sys.argv[1:]:
    try: fd = open(f, "a")
    except OSError: continue
    try: fcntl.lockf(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: sys.exit(0)
    finally: fd.close()
sys.exit(1)' /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock
}
apt_holder() { command -v fuser > /dev/null || return
  fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock 2> /dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' |
    head -1 | xargs -r ps -o comm= -p 2> /dev/null; }
wait_apt() {
  [ "$DRY" = 1 ] && return 0
  local waited=0 who
  while apt_busy; do
    who="$(apt_holder)"
    [ $((waited % 15)) -eq 0 ] && echo "… aguardando ${who:-outro programa} liberar o APT (${waited}s)"
    prog -1 "Aguardando ${who:-outro programa} liberar o APT"
    sleep 3; waited=$((waited + 3))
    [ $waited -ge 900 ] && { echo "✘ o APT continua ocupado por ${who:-outro programa} há 15 min"; return 1; }
  done
}
# apt_do <args>  — espera a trava, roda, e tenta de novo se outro programa pegou a trava no meio
apt_do() {
  local try rc
  for try in 1 2 3; do
    wait_apt || return 1
    runt $T_APT "${APT[@]}" "$@"; rc=$?
    [ $rc -eq 0 ] && return 0
    [ "$DRY" = 1 ] && return $rc
    apt_busy || [ $rc -eq 124 ] || return $rc      # erro real (não é trava): não insiste
    echo "↻ o APT foi travado por outro programa; tentando de novo ($try/3)"
  done
  return $rc
}
APT_FRESH=0
apt_update() { [ "$APT_FRESH" = 1 ] && return 0; apt_do update && APT_FRESH=1; }

# Conserta instalações interrompidas (ex.: computador reiniciado no meio de uma instalação)
recover_dpkg() {
  [ "$DRY" = 1 ] && return 0
  if [ -n "$(dpkg --audit 2> /dev/null)" ] || ls /var/lib/dpkg/updates/0* > /dev/null 2>&1; then
    echo "→ consertando instalação interrompida (dpkg --configure -a)"
    wait_apt; PLO=0 PHI=100 runt $T_APT dpkg --configure -a --force-confdef --force-confold
    runt $T_APT "${APT[@]}" -f install
  fi
}

pkg_ok() { dpkg-query -W -f='${Status}' "$1" 2> /dev/null | grep -q 'ok installed'; }
flat_ok() { command -v flatpak > /dev/null && flatpak info "$1" > /dev/null 2>&1; }

# ── Uma fonte (método:alvo) está instalada? ──
ext_dir() { local d; for d in "$HOME/.local/share/gnome-shell/extensions/$1" "/usr/share/gnome-shell/extensions/$1"; do
  [ -f "$d/metadata.json" ] && { echo "$d"; return 0; }; done; return 1; }
src_installed() {
  local m=${1%%:*} t=${1#*:}
  case "$m" in
    apt)    pkg_ok "${t%%,*}" ;;
    acapt)  pkg_ok "$t" ;;
    deb)    pkg_ok "${t%%=*}" ;;
    snap)   snap list "$t" > /dev/null 2>&1 ;;
    flatpak|acflat) flat_ok "$t" ;;
    ext)    ext_dir "$t" > /dev/null ;;
    fn)     case "$t" in
              flatpak) command -v flatpak > /dev/null && flatpak remotes --system 2> /dev/null | grep -q '^flathub' ;;
              anydesk) pkg_ok anydesk ;;
              *) return 1 ;;
            esac ;;
    *) return 1 ;;
  esac
}
is_installed() { local s; for s in ${SRCS[$1]}; do src_installed "$s" && return 0; done; return 1; }
installed_via() { local s; for s in ${SRCS[$1]}; do src_installed "$s" && { echo "$s"; return 0; }; done; return 1; }

# ─────────────────────── preparação (root, uma vez) ───────────────────────
PK_MASKED=0
restore_pk() { [ "$PK_MASKED" = 1 ] && systemctl unmask --runtime packagekit.service > /dev/null 2>&1; PK_MASKED=0; }
prep_system() {
  CUR=prep
  echo "@@PHASE Preparando o sistema"
  echo "==> Preparando o sistema"
  if [ "$DRY" = 1 ]; then PLO=0 PHI=100 fake preparação; return 0; fi
  # O PackageKit (atualizador em segundo plano / App Center) pega a trava do APT no meio da instalação.
  # Fica pausado só durante a instalação (--runtime: volta sozinho no próximo boot, e é desfeito ao sair).
  if systemctl list-unit-files packagekit.service > /dev/null 2>&1; then
    prog 5 "Pausando o atualizador automático (PackageKit)"
    systemctl mask --runtime packagekit.service > /dev/null 2>&1 && PK_MASKED=1
    systemctl stop packagekit.service > /dev/null 2>&1 || true
  fi
  prog 15 "Aguardando outros instaladores"
  wait_apt
  prog 30 "Verificando instalações interrompidas"
  PLO=30 PHI=50 recover_dpkg
  local need=() p
  for p in curl ca-certificates; do pkg_ok "$p" || need+=("$p"); done
  PLO=50 PHI=75 apt_update || echo "⚠ apt update falhou; seguindo com as listas atuais"
  if [ ${#need[@]} -gt 0 ]; then
    echo "→ instalando ferramentas que faltam: ${need[*]}"
    PLO=75 PHI=100 apt_do install "${need[@]}" || echo "⚠ não consegui instalar ${need[*]}"
  fi
  prog 100 "Sistema pronto"
}

# ── Funções especiais (rodam como root) ──
do_update() {
  PLO=0 PHI=10 apt_update || return 1
  PLO=10 PHI=60 apt_do upgrade || return 1
  if command -v snap > /dev/null; then   # snap refresh não pode bloquear o resto
    PLO=60 PHI=62 runt 120 snap wait system seed.loaded
    PLO=62 PHI=80 runp 900 snap refresh || echo "⚠ snap refresh não terminou; seguindo"
  fi
  if command -v flatpak > /dev/null; then PLO=80 PHI=100 runp $T_FLAT flatpak update -y --system || true; fi
  return 0
}
do_repair() {
  run apt-get clean
  PLO=0 PHI=40 runt $T_APT dpkg --configure -a --force-confdef --force-confold
  PLO=40 PHI=80 apt_do -f install || return 1
  APT_FRESH=0; PLO=80 PHI=100 apt_update
}
do_flatpak() {
  if ! command -v flatpak > /dev/null; then
    PLO=0 PHI=80 apt_do install flatpak gnome-software-plugin-flatpak || PLO=0 PHI=80 apt_do install flatpak || return 1
  fi
  PLO=80 PHI=100 runt $T_NET flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}
do_anydesk() {
  run install -d -m 755 /etc/apt/keyrings
  PLO=0 PHI=5 runt $T_NET curl -fsSL --retry 3 -o /etc/apt/keyrings/keys.anydesk.com.asc https://keys.anydesk.com/repos/DEB-GPG-KEY || return 1
  echo "\$ echo 'deb [signed-by=...] https://deb.anydesk.com all main' > /etc/apt/sources.list.d/anydesk-stable.list"
  [ "$DRY" = 1 ] || echo "deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main" \
    > /etc/apt/sources.list.d/anydesk-stable.list
  APT_FRESH=0; PLO=5 PHI=20 apt_update && PLO=20 PHI=100 apt_do install anydesk
}
ensure_flathub() { src_installed fn:flatpak || [ "$DRY" = 1 ] || do_flatpak; }
# Repositório APT da ArtCraft (pacotes vêm das GitHub Releases oficiais; o índice ainda não é assinado)
AC_LIST=/etc/apt/sources.list.d/artcraft.list
ensure_artcraft_apt() {
  [ -f "$AC_LIST" ] && [ "$APT_FRESH" = 1 ] && return 0
  if [ ! -f "$AC_LIST" ]; then
    echo "\$ echo 'deb [trusted=yes] https://getartcraft.com/apt stable main' > $AC_LIST"
    [ "$DRY" = 1 ] || echo "deb [trusted=yes] https://getartcraft.com/apt stable main" > "$AC_LIST"
    APT_FRESH=0
  fi
  PLO=0 PHI=15 apt_update
}
ensure_artcraft_flat() {
  ensure_flathub || return 1
  flatpak remotes --system 2> /dev/null | grep -q '^artcraft-oci' && return 0
  runt $T_NET flatpak remote-add --system --if-not-exists artcraft-oci https://getartcraft.com/artcraft-oci.flatpakrepo
}

# ── Instala por UMA fonte ──
install_src() {
  local m=${1%%:*} t=${1#*:}
  PLO=0 PHI=100
  case "$m" in
    fn)      "do_${t//-/_}" ;;
    apt)     apt_do install ${t//,/ } ;;
    acapt)   ensure_artcraft_apt && PLO=15 PHI=100 apt_do install "$t" ;;
    snap)    runp $T_SNAP snap install "$t" || { echo "→ tentando de novo com --classic"; runp $T_SNAP snap install "$t" --classic; } ;;
    flatpak) ensure_flathub && runp $T_FLAT flatpak install -y --system flathub "$t" ;;
    acflat)  ensure_artcraft_flat && runp $T_FLAT flatpak install -y --system artcraft-oci "$t" ;;
    deb)
      local pkg=${t%%=*} url=${t#*=} tmp rc
      tmp="$(mktemp -d)"; chmod 755 "$tmp"
      PLO=0 PHI=45 runp $T_NET curl -fL -# --retry 3 --connect-timeout 30 -o "$tmp/$pkg.deb" "$url"; rc=$?
      if [ $rc -eq 0 ]; then
        [ "$DRY" = 1 ] || chmod 644 "$tmp/$pkg.deb"
        PLO=45 PHI=100 apt_do install "$tmp/$pkg.deb"; rc=$?
      fi
      rm -rf "$tmp"; return $rc ;;
    *) echo "fonte desconhecida: $1"; return 1 ;;
  esac
}

# ── Instala um item: tenta cada fonte em ordem e CONFERE se instalou ──
install_item() {
  local id=$1 s via rc
  if [ "${METH[$id]}" != fn ] && via="$(installed_via "$id")"; then
    echo "✔ já instalado (${via%%:*})"; echo "@@VIA $id ${via%%:*}"; return 0
  fi
  for s in ${SRCS[$id]}; do
    echo "→ tentando ${s%%:*}: ${s#*:}"
    prog 0 "Instalando via ${s%%:*}"
    install_src "$s"; rc=$?
    [ "$DRY" = 1 ] && { echo "@@VIA $id ${s%%:*}"; return $rc; }
    if [ "${s%%:*}" = fn ] && [ "${s#*:}" != flatpak ] && [ "${s#*:}" != anydesk ]; then return $rc; fi
    if src_installed "$s"; then echo "✔ instalado e verificado via ${s%%:*}"; echo "@@VIA $id ${s%%:*}"; return 0; fi
    echo "✘ não instalou via ${s%%:*} (código $rc) — tentando a próxima fonte"
    recover_dpkg
  done
  echo "✘ nenhuma fonte funcionou para ${NAME[$id]}"
  return 1
}

# ─────────────────────── extensões GNOME (como o usuário) ───────────────────────
# Download sem depender de curl (foi o que fez o Compiz falhar: "curl: comando não encontrado")
fetch() {  # fetch <url> [arquivo]  — sem arquivo, imprime o conteúdo
  python3 -I - "$@" <<'EOF'
import sys, urllib.request
url, out = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else None)
req = urllib.request.Request(url, headers={"User-Agent": "ViskooOS-Apps"})
with urllib.request.urlopen(req, timeout=60) as r:
    if not out:
        sys.stdout.write(r.read().decode()); sys.exit(0)
    total, done, last = int(r.headers.get("Content-Length") or 0), 0, -1
    with open(out, "wb") as f:
        while chunk := r.read(65536):
            f.write(chunk); done += len(chunk)
            if total and (p := done * 100 // total) != last:
                print(f"baixando {p}%", flush=True); last = p
EOF
}
ext_enable() {   # deixa a extensão ligada (agora, se o Shell já carregou; senão, no próximo login)
  local uuid=$1 cur new
  gsettings set org.gnome.shell disable-user-extensions false 2> /dev/null
  cur="$(gsettings get org.gnome.shell enabled-extensions 2> /dev/null)"
  if [[ "$cur" != *"'$uuid'"* ]]; then
    if [[ "$cur" == "@as []" || "$cur" == "[]" || -z "$cur" ]]; then new="['$uuid']"; else new="${cur%]}, '$uuid']"; fi
    gsettings set org.gnome.shell enabled-extensions "$new"
  fi
  gsettings get org.gnome.shell disabled-extensions 2> /dev/null | grep -q "'$uuid'" &&
    gsettings set org.gnome.shell disabled-extensions "$(gsettings get org.gnome.shell disabled-extensions |
      python3 -I -c 'import ast,sys;u=sys.argv[1];l=[x for x in ast.literal_eval(sys.stdin.read().replace("@as ","")) if x!=u];print(l)' "$uuid")"
  gnome-extensions enable "$uuid" 2> /dev/null || true
}
ext_loaded() { gnome-extensions info "$1" 2> /dev/null | grep -qE '^ *(Estado|State): *ACTIVE'; }
install_ext() {
  local uuid=$1 shell json url tmp rc out
  if ext_dir "$uuid" > /dev/null; then
    echo "✔ já instalada em $(ext_dir "$uuid")"; [ "$DRY" = 1 ] || ext_enable "$uuid"
    ext_loaded "$uuid" || echo "@@NOTE relog"
    return 0
  fi
  shell="$(gnome-shell --version 2> /dev/null | grep -oE '[0-9]+' | head -1)"
  prog 10 "Consultando extensions.gnome.org (GNOME $shell)"
  echo "→ procurando versão para o GNOME $shell"
  json="$(fetch "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell" 2>&1)" || {
    echo "✘ não consegui falar com extensions.gnome.org: ${json##*$'\n'}"; return 1; }
  url="$(python3 -I -c 'import json,sys;print(json.load(sys.stdin).get("download_url") or "")' <<< "$json" 2> /dev/null)"
  [ -n "$url" ] || { echo "✘ a extensão não tem versão para o GNOME $shell"; return 1; }
  [ "$DRY" = 1 ] && { echo "\$ (instalaria https://extensions.gnome.org$url)"; PLO=20 PHI=100 fake extensão; return 0; }

  # 1º jeito: pedir ao próprio GNOME Shell — instala e ATIVA NA HORA (sem sair da sessão).
  # O GNOME mostra uma janela de confirmação; o usuário clica em "Instalar".
  if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v gdbus > /dev/null; then
    echo "\$ gdbus … org.gnome.Shell.Extensions.InstallRemoteExtension $uuid"
    prog -1 "Clique em “Instalar” na janela do GNOME"
    echo "@@ASK $CUR Confirme na janela do GNOME que apareceu"
    out="$(timeout 240 gdbus call --session --timeout 230 --dest org.gnome.Shell --object-path /org/gnome/Shell \
      --method org.gnome.Shell.Extensions.InstallRemoteExtension "$uuid" 2>&1)"; echo "$out"
    if [[ "$out" == *successful* ]] && ext_dir "$uuid" > /dev/null; then
      ext_enable "$uuid"; echo "✔ instalada e ativada (sem precisar sair da sessão)"; return 0
    fi
    [[ "$out" == *cancelled* ]] && echo "→ confirmação recusada/fechada; instalando pelo arquivo .zip"
  fi

  # 2º jeito: baixar o .zip e instalar (ativa no próximo login, no Wayland)
  tmp="$(mktemp -d)"
  PLO=30 PHI=85
  echo "\$ baixando https://extensions.gnome.org$url"
  fetch "https://extensions.gnome.org$url" "$tmp/ext.zip" 2>&1 | pf; rc=${PIPESTATUS[0]}
  if [ $rc -eq 0 ]; then
    prog 90 "Instalando a extensão"
    echo "\$ gnome-extensions install --force ext.zip"
    gnome-extensions install --force "$tmp/ext.zip" 2>&1; rc=$?
  fi
  rm -rf "$tmp"; [ $rc -eq 0 ] || { echo "✘ falhou (código $rc)"; return $rc; }
  ext_enable "$uuid"
  echo "✔ instalada; ativa depois de sair e entrar na sessão"; echo "@@NOTE relog"
}

# ─────────────────── fila: cada item isolado no seu processo ───────────────────
ctl_has() { [ -n "$CONTROL" ] && [ -f "$CONTROL" ] && grep -qxF "$1" "$CONTROL" 2> /dev/null; }
descendants() { local c; for c in $(pgrep -P "$1" 2> /dev/null); do descendants "$c"; echo "$c"; done; }
kill_tree() {   # mata o item inteiro (ele e todos os filhos: apt, flatpak, curl, timeout…)
  local i pids; pids="$(descendants "$1") $1"
  kill -TERM $pids 2> /dev/null
  for i in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$1" 2> /dev/null || break; sleep 1; done
  kill -KILL $pids 2> /dev/null; return 0
}
run_items() {   # $1 = "root" ou "user"
  local who=$1; shift
  local id pid rc reason t0
  for id in "$@"; do
    [ -n "${NAME[$id]:-}" ] || { echo "@@FAIL $id item desconhecido"; continue; }
    if ctl_has cancel; then echo "@@SKIP $id"; continue; fi
    CUR=$id
    echo "@@STEP $id"
    echo "==> ${NAME[$id]}"
    t0=$SECONDS reason=""
    if [ "$who" = user ]; then ( CUR=$id; install_ext "$(tgt_of "$id" ext)" ) < /dev/null 2>&1 &
    else ( CUR=$id; install_item "$id" ) < /dev/null 2>&1 &
    fi
    pid=$!
    while kill -0 "$pid" 2> /dev/null; do
      if ctl_has "skip $id" || ctl_has cancel; then reason=skip; echo "⏭ interrompido a pedido"; kill_tree "$pid"; break; fi
      if [ $((SECONDS - t0)) -gt $T_ITEM ]; then reason=timeout; echo "⚠ passou de $((T_ITEM / 60)) min; interrompendo"; kill_tree "$pid"; break; fi
      sleep 0.5
    done
    wait "$pid" 2> /dev/null; rc=$?
    [ "$who" = root ] && [ -n "$reason" ] && { CUR=$id; recover_dpkg; }
    case "$reason" in
      skip)    echo "@@SKIP $id" ;;
      timeout) echo "@@FAIL $id tempo esgotado" ;;
      *)       if [ $rc -eq 0 ]; then echo "@@OK $id"; else echo "@@FAIL $id código $rc"; fi ;;
    esac
  done
}

# ── Ajustes pós-instalação que rodam como o USUÁRIO (sem marcadores; não contam como item) ──
# Para um app ganhar um ajuste, crie user_post_<id> (hífens viram _).
user_post_zen() { bash "$ROOT/ViskooOS/zen/apply-zen-theme.sh"; }
run_post_user() {
  local id f
  for id in "$@"; do
    f="user_post_${id//-/_}"
    declare -F "$f" > /dev/null || continue
    is_installed "$id" || continue
    echo "→ aplicando o design ViskooOS em ${NAME[$id]}"
    [ "$DRY" = 1 ] && continue
    "$f" 2>&1 || echo "⚠ ajuste de ${NAME[$id]} não foi aplicado"
  done
}

# ─────────────────────────────── modos internos ───────────────────────────────
parse_internal() {   # [--dry-run] [--control arquivo] ids...
  ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY=1 ;;
      --control) CONTROL=${2:-}; shift ;;
      *) ARGS+=("$1") ;;
    esac; shift
  done
}
case "${1:-}" in
  --worker)   # parte que precisa de root (chamada via pkexec/sudo)
    shift; parse_internal "$@"
    trap '' PIPE                     # se a janela fechar, a instalação termina do mesmo jeito
    if [ "$DRY" = 0 ]; then
      [ "$(id -u)" -eq 0 ] || { echo "precisa de root"; exit 1; }
      exec 9> /run/viskooos-apps.lock
      flock -n 9 || { echo "✘ outra instalação do ViskooOS Apps já está rodando"; echo "@@BUSY"; exit 3; }
      RLOG=/var/log/viskooos-apps.log
      { echo; echo "===== $(date '+%F %T')  worker  ${ARGS[*]}"; } >> "$RLOG"
      exec > >(tee -a -p "$RLOG") 2>&1
      trap 'restore_pk' EXIT
    fi
    prep_system
    run_items root "${ARGS[@]}"
    restore_pk
    echo "@@DONE"; exit 0 ;;
  --worker-user)   # extensões GNOME (como o usuário)
    shift; parse_internal "$@"; run_items user "${ARGS[@]}"; exit 0 ;;
  --post-user)     # ajustes pós-instalação como o usuário
    shift; parse_internal "$@"; run_post_user "${ARGS[@]}"; exit 0 ;;
  --catalog)       # catálogo para a interface (TSV: id def cat nome desc método instalado fontes)
    for id in "${IDS[@]}"; do
      inst=0; is_installed "$id" && inst=1
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "${DEF[$id]}" "${CAT[$id]}" "${NAME[$id]}" "${DESC[$id]}" "${METH[$id]}" "$inst" "${SRCS[$id]}"
    done; exit 0 ;;
esac

# ────────────────────────────── INTERFACE ──────────────────────────────
MODE=gui
for a in "$@"; do
  case "$a" in
    --tui) MODE=tui ;;
    --zenity) MODE=zenity ;;
    --dry-run) DRY=1 ;;
    --list) MODE=list ;;
    -h|--help) sed -n '2,11p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opção desconhecida: $a"; exit 1 ;;
  esac
done
[ "$(id -u)" -ne 0 ] || { echo "Não rode como root; o instalador pede a senha quando precisa."; exit 1; }
HAS_DISPLAY=0; [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && HAS_DISPLAY=1
GUI_PY="$ROOT/viskooos-apps.py"
adw_ok() { python3 -I -c 'import gi; gi.require_version("Gtk","4.0"); gi.require_version("Adw","1")' 2> /dev/null; }
NEW_GUI=0
if [ "$MODE" = gui ] && [ "$HAS_DISPLAY" = 1 ] && [ -f "$GUI_PY" ] && adw_ok; then NEW_GUI=1
else
  [ "$MODE" = zenity ] && MODE=gui
  if [ "$MODE" = gui ] && { [ "$HAS_DISPLAY" = 0 ] || ! command -v zenity > /dev/null; }; then MODE=tui; fi
fi

STATE="$HOME/.local/share/viskooos"; mkdir -p "$STATE"
LOG="$STATE/install-apps.log"
OUT=/dev/null; [ -t 1 ] && OUT=/dev/tty

# Atalho no menu de aplicativos (ViskooOS Apps)
DESK="$HOME/.local/share/applications/viskooos-apps.desktop"
ICON="$ROOT/ViskooOS/plymouth/logo.png"; [ -f "$ICON" ] || ICON=system-software-install
[ -f "$STATE/sem-marca" ] && ICON=system-software-install
mkdir -p "$(dirname "$DESK")"
cat > "$DESK" <<EOF
[Desktop Entry]
Type=Application
Name=$TITLE
Comment=Escolha e instale aplicativos
Exec=bash "$SELF"
Icon=$ICON
Terminal=false
Categories=System;PackageManager;
Keywords=instalar;apps;programas;compiz;artcraft;
StartupWMClass=com.viskooos.Apps
EOF
grep -qx "$DESK" "$STATE/files.manifest" 2> /dev/null || echo "$DESK" >> "$STATE/files.manifest"

if [ "$NEW_GUI" = 1 ]; then
  dargs=(); [ "$DRY" = 1 ] && dargs=(--dry-run)
  exec python3 -I "$GUI_PY" --backend "$SELF" "${dargs[@]}"
fi

status_of() { if is_installed "$1"; then echo "✔ instalado"; else echo ""; fi; }

if [ "$MODE" = list ]; then
  for id in "${IDS[@]}"; do printf '%-14s %-16s %-26s %s\n' "$id" "${CAT[$id]}" "${NAME[$id]}" "$(status_of "$id")"; done
  exit 0
fi

die() { if [ "$MODE" = gui ]; then zenity --error --title="$TITLE" --text="$1" 2> /dev/null; else echo "$1"; fi; exit 1; }

# 1. Escolha dos apps
SEL=()
if [ "$MODE" = gui ]; then
  rows=()
  for id in "${IDS[@]}"; do
    st="$(status_of "$id")"; on=FALSE
    [ "${DEF[$id]}" = 1 ] && { [ -z "$st" ] || [ "${METH[$id]}" = fn ]; } && on=TRUE
    rows+=("$on" "$id" "${CAT[$id]}" "${NAME[$id]}" "${DESC[$id]}" "$st")
  done
  choice="$(zenity --list --checklist --title="$TITLE" \
    --text="Marque os aplicativos que deseja instalar e clique em <b>Instalar</b>." \
    --width=980 --height=720 --ok-label="Instalar" --cancel-label="Cancelar" \
    --column="" --column="id" --column="Categoria" --column="Aplicativo" --column="Descrição" --column="Status" \
    --hide-column=2 --print-column=2 --separator='|' "${rows[@]}" 2> /dev/null)" || exit 0
  IFS='|' read -r -a SEL <<< "$choice"
else
  command -v whiptail > /dev/null || die "whiptail não encontrado (sudo apt install whiptail)."
  rows=()
  for id in "${IDS[@]}"; do
    st="$(status_of "$id")"; on=OFF
    [ "${DEF[$id]}" = 1 ] && { [ -z "$st" ] || [ "${METH[$id]}" = fn ]; } && on=ON
    rows+=("$id" "$(printf '%-15s %-24s %s' "${CAT[$id]}" "${NAME[$id]}" "$st")" "$on")
  done
  choice="$(whiptail --title "$TITLE" --separate-output --checklist \
    "ESPAÇO marca/desmarca, ENTER confirma." 32 90 24 "${rows[@]}" 3>&1 1>&2 2>&3)" || exit 0
  mapfile -t SEL <<< "$choice"
fi

# mantém a ordem do catálogo (sistema primeiro) e separa root x usuário
ROOT_IDS=(); USER_IDS=()
for id in "${IDS[@]}"; do
  for s in "${SEL[@]}"; do
    [ "$s" = "$id" ] || continue
    if [ "${METH[$id]}" = ext ]; then USER_IDS+=("$id"); else ROOT_IDS+=("$id"); fi
  done
done
TOTAL=$(( ${#ROOT_IDS[@]} + ${#USER_IDS[@]} ))
[ "$TOTAL" -gt 0 ] || die "Nenhum aplicativo selecionado."

# 2. Execução — lê os marcadores @@ e alimenta a barra de progresso / terminal
RESULTS="$STATE/install-apps.results"; : > "$RESULTS"
{ echo; echo "===== $(date '+%F %T')  $TITLE  ${ROOT_IDS[*]} ${USER_IDS[*]}"; } >> "$LOG"

dryflag=(); [ "$DRY" = 1 ] && dryflag=(--dry-run)
elevate() {
  [ ${#ROOT_IDS[@]} -gt 0 ] || return 0
  if [ "$DRY" = 1 ]; then bash "$SELF" --worker --dry-run "${ROOT_IDS[@]}"
  elif [ "$MODE" = gui ]; then pkexec bash "$SELF" --worker "${ROOT_IDS[@]}" || echo "@@AUTHFAIL $?"
  else sudo bash "$SELF" --worker "${ROOT_IDS[@]}" || echo "@@AUTHFAIL $?"
  fi
}
everything() { elevate; bash "$SELF" --worker-user "${dryflag[@]}" "${USER_IDS[@]}"; run_post_user "${ROOT_IDS[@]}"; }

done_n=0 cur_name="Preparando o sistema"
bar() {   # barra de texto no terminal
  local p=$1 w=30 f; f=$(( p * w / 100 ))
  printf '\r\033[K  \033[38;5;208m%s\033[38;5;240m%s\033[0m %3d%%  %s' \
    "$(printf '%*s' "$f" '' | tr ' ' '█')" "$(printf '%*s' $((w - f)) '' | tr ' ' '░')" "$p" "${2:0:50}" > "$OUT"
}
parse() {
  local line id p rest
  while IFS= read -r line; do
    case "$line" in
      "@@STEP "*)
        id=${line#@@STEP }; cur_name=${NAME[$id]:-$id}
        echo "$(( done_n * 100 / TOTAL ))"
        echo "# $cur_name  ($((done_n + 1)) de $TOTAL)…"
        printf '\r\033[K\n\033[1;38;5;208m==> %s\033[0m  (%d de %d)\n' "$cur_name" $((done_n + 1)) "$TOTAL" > "$OUT"
        echo "--- $cur_name" >> "$LOG" ;;
      "@@PROG "*)
        rest=${line#@@PROG }; [ "${rest%% *}" = prep ] && continue
        rest=${rest#* }; p=${rest%%$'\t'*}
        [ "$p" -ge 0 ] 2> /dev/null || continue
        echo "$(( (done_n * 100 + p) / TOTAL ))"
        bar "$p" "${rest#*$'\t'}" ;;
      "@@OK "*|"@@FAIL "*|"@@SKIP "*)
        rest=${line#@@* }; id=${rest%% *}; done_n=$((done_n + 1))
        echo "${line%% *}|$id" >> "$RESULTS"
        case "$line" in "@@OK "*) printf '\r\033[K  \033[32m✔ %s\033[0m\n' "$cur_name" > "$OUT" ;;
          *) printf '\r\033[K  \033[31m✘ %s\033[0m\n' "$cur_name" > "$OUT" ;; esac
        echo "$(( done_n * 100 / TOTAL ))" ;;
      "@@AUTHFAIL"*) echo "AUTH" >> "$RESULTS" ;;
      "@@NOTE relog") echo "RELOG" >> "$RESULTS" ;;
      "@@PHASE "*) echo "# ${line#@@PHASE }…" ;;
      "@@"*) ;;
      *) echo "$line" >> "$LOG"; printf '\r\033[K\033[38;5;245m%s\033[0m\n' "${line:0:200}" > "$OUT" ;;
    esac
  done
  echo 100
}

if [ "$MODE" = gui ]; then
  everything 2>&1 | parse | zenity --progress --title="$TITLE" --text="Preparando…" \
    --percentage=0 --auto-close --no-cancel --width=560 2> /dev/null
else
  if [ ${#ROOT_IDS[@]} -gt 0 ] && [ "$DRY" = 0 ]; then sudo -v || die "Senha não confirmada."; fi
  everything 2>&1 | parse > /dev/null
fi

# 3. Resumo
ok=(); fail=(); need_relog=0
while IFS='|' read -r st id; do
  [ -n "${id:-}" ] || continue
  if [ "$st" = "@@OK" ]; then ok+=("${NAME[$id]}")
  elif [ "$st" = "@@SKIP" ]; then fail+=("${NAME[$id]} (pulado)")
  else fail+=("${NAME[$id]}"); fi
done < "$RESULTS"
grep -qx RELOG "$RESULTS" && need_relog=1
for id in "${ROOT_IDS[@]}" "${USER_IDS[@]}"; do   # itens que nem chegaram a rodar (ex.: senha cancelada)
  grep -q "|$id\$" "$RESULTS" || fail+=("${NAME[$id]} (não executado)")
done

msg="Instalados: ${#ok[@]}   Falharam: ${#fail[@]}"
[ ${#ok[@]} -gt 0 ] && msg+=$'\n\n✔ '"$(printf '%s, ' "${ok[@]}" | sed 's/, $//')"
[ ${#fail[@]} -gt 0 ] && msg+=$'\n\n✘ '"$(printf '%s, ' "${fail[@]}" | sed 's/, $//')"$'\n\nDetalhes no log: '"$LOG"
[ "$need_relog" = 1 ] && msg+=$'\n\nEfeitos Compiz: faça LOGOUT e LOGIN para ativar. Ajuste em Gerenciador de Extensões.'
grep -qx AUTH "$RESULTS" && msg="Senha cancelada ou recusada — os apps do sistema não foram instalados."$'\n\n'"$msg"
[ "$DRY" = 1 ] && msg="(simulação — nada foi instalado)"$'\n\n'"$msg"

if [ "$MODE" = gui ]; then
  if [ ${#fail[@]} -gt 0 ]; then zenity --warning --title="$TITLE" --width=480 --text="$msg" 2> /dev/null
  else zenity --info --title="$TITLE" --width=480 --text="$msg" 2> /dev/null; fi
else
  printf '\n\033[1;38;5;208m==> Concluído\033[0m\n%s\n' "$msg"
fi
