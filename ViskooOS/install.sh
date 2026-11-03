#!/usr/bin/env bash
# ViskooOS — instalador de personalização do Ubuntu GNOME
# Uso:  bash install.sh
# Variáveis opcionais (ex.: GTK_THEME="Plastik-Dark" bash install.sh):
#   GTK_THEME, SHELL_THEME, ICON_THEME, CURSOR_THEME, WALLPAPER, SKIP_APT=1, SKIP_BOOT=1, SKIP_BRANDING=1
# Para desfazer:  bash uninstall.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/ViskooOS"

# Kit ViskooOS (modo escuro + laranja): gerado por ViskooOS/viskooos-kit/build.py
GTK_THEME="${GTK_THEME:-ViskooOS}"
SHELL_THEME="${SHELL_THEME:-ViskooOS}"
ICON_THEME="${ICON_THEME:-ViskooOS}"      # inclui o logo ViskooOS no botão "Mostrar aplicativos" do dock
CURSOR_THEME="${CURSOR_THEME:-ViskooOS}"
ACCENT_COLOR="${ACCENT_COLOR:-orange}"
WALLPAPER="${WALLPAPER:-motocicleta-custom-em-garagem-industrial.png}"   # nome do arquivo em ViskooOS/wallpapers
BUTTON_LAYOUT="${BUTTON_LAYOUT:-close,minimize,maximize:}"   # botões da janela à esquerda (fechar, minimizar, maximizar)
# Dock ViskooOS: embaixo, flutuante (cantos arredondados), auto-ocultar, ícones 56px, logo ViskooOS em 1º lugar
declare -A DOCK=(
  [dock-position]="'BOTTOM'" [extend-height]=false [dock-fixed]=false [autohide]=true
  [intellihide]=true [dash-max-icon-size]=56 [show-apps-at-top]=true [show-trash]=false
  [show-mounts]=true [click-action]="'focus-or-appspread'" [transparency-mode]="'DEFAULT'"
)
UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
PACKAGES=(gnome-tweaks gnome-shell-extension-manager gnome-shell-extensions qt-style-kvantum)

# Estado usado pelo uninstall.sh
STATE="$HOME/.local/share/viskooos"
BACKUP="$STATE/gsettings.backup"     # valores originais (salvos só na 1ª instalação)
MANIFEST="$STATE/files.manifest"     # arquivos/pastas criados pelo instalador
PKGS_NEW="$STATE/packages.new"       # pacotes que NÃO existiam antes

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ -d "$SRC" ] || { echo "Pasta $SRC não encontrada."; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Não rode como root; o script pede sudo quando precisa."; exit 1; }
mkdir -p "$STATE"
touch "$MANIFEST" "$PKGS_NEW"

# Registra um caminho no manifesto apenas se ele ainda não existir (não apaga nada seu depois)
track() { [ -e "$1" ] || echo "$1" >> "$MANIFEST"; }
# Copia src -> dest registrando dest
put() {
  track "$2"; mkdir -p "$(dirname "$2")"
  if [ -d "$1" ]; then mkdir -p "$2"; cp -a "$1/." "$2/"; else cp -a "$1" "$2"; fi
}

# gsettings do User Themes (o schema pode não estar compilado globalmente)
SCHEMADIR="/usr/share/gnome-shell/extensions/$UUID/schemas"
ut() {
  if gsettings list-schemas | grep -qx org.gnome.shell.extensions.user-theme; then
    gsettings "$@"
  elif [ -d "$SCHEMADIR" ]; then
    gsettings --schemadir "$SCHEMADIR" "$@"
  else
    return 1
  fi
}

# 0. Backup das configurações atuais (somente na primeira vez)
if [ ! -s "$BACKUP" ]; then
  log "Salvando configurações atuais em $BACKUP"
  {
    for k in gtk-theme icon-theme cursor-theme color-scheme accent-color; do
      echo "org.gnome.desktop.interface|$k|$(gsettings get org.gnome.desktop.interface $k)"
    done
    for k in picture-uri picture-uri-dark picture-options; do
      echo "org.gnome.desktop.background|$k|$(gsettings get org.gnome.desktop.background $k)"
    done
    echo "org.gnome.desktop.wm.preferences|button-layout|$(gsettings get org.gnome.desktop.wm.preferences button-layout)"
    echo "org.gnome.desktop.screensaver|picture-uri|$(gsettings get org.gnome.desktop.screensaver picture-uri)"
    for k in "${!DOCK[@]}"; do
      echo "org.gnome.shell.extensions.dash-to-dock|$k|$(gsettings get org.gnome.shell.extensions.dash-to-dock $k 2>/dev/null || echo "''")"
    done
    for k in enabled-extensions disable-user-extensions; do
      echo "org.gnome.shell|$k|$(gsettings get org.gnome.shell $k)"
    done
    if v="$(ut get org.gnome.shell.extensions.user-theme name 2>/dev/null)"; then
      echo "org.gnome.shell.extensions.user-theme|name|$v"
    else
      echo "org.gnome.shell.extensions.user-theme|name|''"
    fi
  } > "$BACKUP"
else
  log "Backup já existe ($BACKUP) — mantendo o original"
fi

# 1. Pacotes
if [ "${SKIP_APT:-0}" != "1" ]; then
  log "Instalando pacotes (sudo)"
  for p in "${PACKAGES[@]}"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then
      grep -qx "$p" "$PKGS_NEW" || echo "$p" >> "$PKGS_NEW"
    fi
  done
  sudo apt update
  sudo apt install -y "${PACKAGES[@]}"
fi

# 2. Pastas de destino
log "Criando pastas"
for d in ~/.themes ~/.icons ~/.config/Kvantum ~/.local/share/plank ~/.local/share/plank/themes ~/.local/share/backgrounds; do
  track "$d"; mkdir -p "$d"
done

# 3. Temas GTK / Shell  (_.themes -> ~/.themes), exceto os que não são tema GTK
log "Copiando temas GTK/Shell para ~/.themes"
for d in "$SRC/_.themes"/*/; do
  name="$(basename "$d")"
  case "$name" in
    dolphin|KvGlow-MojaveDark|Mojave-dark|macOS-Black-Transparency) continue ;;
  esac
  put "${d%/}" ~/.themes/"$name"
done

# 3b. Logos "distributor" do shell-gnome-dark-mode -> assets do tema de shell Dark-Mode
mkdir -p ~/.themes/Dark-Mode/gnome-shell/assets
cp -a "$SRC/shell-gnome-dark-mode/"*.svg ~/.themes/Dark-Mode/gnome-shell/assets/

# 4. Ícones e cursores (_.icons -> ~/.icons) + "dolphin" (é o ícone La Capitaine)
log "Copiando ícones e cursores para ~/.icons"
for d in "$SRC/_.icons"/*/; do
  name="$(basename "$d")"
  put "${d%/}" ~/.icons/"$name"
done
put "$SRC/_.themes/dolphin" ~/.icons/La-Capitaine

# 5. Kvantum (apps Qt) e tema do Plank
log "Copiando temas Kvantum e Plank"
put "$SRC/_.themes/KvGlow-MojaveDark" ~/.config/Kvantum/KvGlow-MojaveDark
put "$SRC/_.themes/Mojave-dark" ~/.config/Kvantum/Mojave-dark
put "$SRC/_.themes/macOS-Black-Transparency" ~/.local/share/plank/themes/macOS-Black-Transparency

# 6. Wallpapers (todos ficam disponíveis em Configurações > Aparência)
log "Instalando wallpapers"
WP_DIR="$HOME/.local/share/backgrounds/viskooos"
track "$WP_DIR"; mkdir -p "$WP_DIR"
# nomes padronizados na cópia: minúsculas, sem acento, sem espaço ("Pôr do Sol.png" -> "por-do-sol.png")
slug() {
  python3 -I -c 'import sys,unicodedata,re
n=unicodedata.normalize("NFKD",sys.argv[1]).encode("ascii","ignore").decode().lower()
b,_,e=n.rpartition(".")
print(re.sub(r"[^a-z0-9]+","-",b).strip("-")+"."+e)' "$1"
}
shopt -s nullglob nocaseglob
for f in "$SRC/wallpapers/"*.{png,jpg,jpeg,webp}; do
  cp -a "$f" "$WP_DIR/$(slug "$(basename "$f")")"
done
shopt -u nocaseglob
XML_DIR="$HOME/.local/share/gnome-background-properties"
track "$XML_DIR"; track "$XML_DIR/viskooos.xml"; mkdir -p "$XML_DIR"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">'
  echo '<wallpapers>'
  for f in "$WP_DIR"/*.{png,jpg,jpeg,webp}; do
    echo "  <wallpaper deleted=\"false\"><name>ViskooOS $(basename "${f%.*}")</name><filename>$f</filename><filename-dark>$f</filename-dark><options>zoom</options><shade_type>solid</shade_type><pcolor>#000000</pcolor><scolor>#000000</scolor></wallpaper>"
  done
  echo '</wallpapers>'
} > "$XML_DIR/viskooos.xml"
WALLPAPER="$(slug "$WALLPAPER")"
[ -f "$WP_DIR/$WALLPAPER" ] || { echo "Wallpaper $WALLPAPER não encontrado em $SRC/wallpapers"; exit 1; }
WP="file://$WP_DIR/$WALLPAPER"
gsettings set org.gnome.desktop.background picture-uri "$WP"
gsettings set org.gnome.desktop.background picture-uri-dark "$WP"
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.screensaver picture-uri "$WP" 2>/dev/null || true

# 7. Aparência
log "Aplicando tema escuro, GTK, ícones e cursor"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface accent-color "$ACCENT_COLOR" 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
gsettings set org.gnome.desktop.wm.preferences button-layout "$BUTTON_LAYOUT"

# 7b. Apps modernos (libadwaita: Configurações, Arquivos...) ignoram o tema GTK;
#     as cores ViskooOS vão em ~/.config/gtk-4.0/gtk.css (o original é guardado para o uninstall)
ADW_CSS="$HOME/.config/gtk-4.0/gtk.css"
mkdir -p "$(dirname "$ADW_CSS")"
if [ -f "$ADW_CSS" ] && ! grep -q 'ViskooOS (libadwaita)' "$ADW_CSS" && [ ! -e "$STATE/gtk4.css.orig" ]; then
  cp -a "$ADW_CSS" "$STATE/gtk4.css.orig"
fi
track "$ADW_CSS"
cp "$SRC/_.themes/ViskooOS/gtk-4.0/libadwaita.css" "$ADW_CSS"

# 7b2. Fontes do sistema: DM Sans (interface/títulos) + DM Mono (terminal/código), as mesmas de viskoo.com.br
log "Instalando fontes DM Sans e DM Mono"
FONT_DIR="$HOME/.local/share/fonts/ViskooOS"
track "$HOME/.local/share/fonts"; track "$FONT_DIR"; mkdir -p "$FONT_DIR"
cp "$SRC/fonts/"*.ttf "$SRC/fonts/OFL-DMSans-DMMono.txt" "$FONT_DIR/"
fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
FONT_BACKUP="$STATE/fonts.backup"   # salvo à parte: instalações antigas não guardavam as fontes
if [ ! -s "$FONT_BACKUP" ]; then
  for k in font-name document-font-name monospace-font-name; do
    echo "org.gnome.desktop.interface|$k|$(gsettings get org.gnome.desktop.interface $k)"
  done > "$FONT_BACKUP"
  echo "org.gnome.desktop.wm.preferences|titlebar-font|$(gsettings get org.gnome.desktop.wm.preferences titlebar-font)" >> "$FONT_BACKUP"
fi
gsettings set org.gnome.desktop.interface font-name 'DM Sans 11'
gsettings set org.gnome.desktop.interface document-font-name 'DM Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'DM Mono 11'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'DM Sans Bold 11'

# 7c. Dock
log "Configurando o dock"
for k in "${!DOCK[@]}"; do
  gsettings set org.gnome.shell.extensions.dash-to-dock "$k" "${DOCK[$k]}" 2>/dev/null || echo "  aviso: não consegui ajustar o dock ($k)"
done

# 8. Extensão User Themes + tema do Shell
log "Ativando extensão User Themes"
gsettings set org.gnome.shell disable-user-extensions false
cur="$(gsettings get org.gnome.shell enabled-extensions)"
if [[ "$cur" != *"$UUID"* ]]; then
  if [[ "$cur" == "@as []" || "$cur" == "[]" ]]; then new="['$UUID']"; else new="${cur%]}, '$UUID']"; fi
  gsettings set org.gnome.shell enabled-extensions "$new"
fi
ut set org.gnome.shell.extensions.user-theme name "$SHELL_THEME" \
  || echo "Schema do User Themes não encontrado; escolha o tema do Shell no Ajustes (gnome-tweaks) após relogar."

# 8b. Logos do Ubuntu -> ViskooOS fora do tema de ícones (pixmaps do sistema e tema de boot reserva).
#     dpkg-divert guarda o original (.ubuntu) e impede que atualizações do Ubuntu tragam o logo de volta.
if [ "${SKIP_BRANDING:-0}" != "1" ]; then
  log "Trocando os logos do Ubuntu pelo logo ViskooOS (sudo)"
  BR="$SRC/branding"
  for pair in \
    "pixmaps/ubuntu-logo.svg:/usr/share/pixmaps/ubuntu-logo.svg" \
    "pixmaps/ubuntu-logo-text.svg:/usr/share/pixmaps/ubuntu-logo-text.svg" \
    "pixmaps/ubuntu-logo-text.png:/usr/share/pixmaps/ubuntu-logo-text.png" \
    "pixmaps/ubuntu-logo-text-dark.svg:/usr/share/pixmaps/ubuntu-logo-text-dark.svg" \
    "pixmaps/ubuntu-logo-text-dark.png:/usr/share/pixmaps/ubuntu-logo-text-dark.png" \
    "plymouth-spinner/watermark.png:/usr/share/plymouth/themes/spinner/watermark.png" \
    "plymouth-spinner/bgrt-fallback.png:/usr/share/plymouth/themes/spinner/bgrt-fallback.png"; do
    src="$BR/${pair%%:*}"; dst="${pair#*:}"
    [ -f "$src" ] || continue
    if ! dpkg-divert --list "$dst" | grep -q viskooos; then
      sudo dpkg-divert --package viskooos --divert "$dst.ubuntu" --rename --add "$dst" >/dev/null
    fi
    sudo install -D -m 644 "$src" "$dst"
  done
fi

# 9. Logo na tela de boot (Plymouth) — precisa de sudo
if [ "${SKIP_BOOT:-0}" != "1" ]; then
  log "Instalando logo ViskooOS na tela de boot (Plymouth)"
  PLY_DIR="/usr/share/plymouth/themes/viskooos"
  PLY_FILE="$PLY_DIR/viskooos.plymouth"
  if [ ! -s "$STATE/plymouth.previous" ]; then
    update-alternatives --query default.plymouth 2>/dev/null | awk '/^Value:/{print $2}' > "$STATE/plymouth.previous"
  fi
  # tema em script, estilo Apple: logo + barra de progresso fina
  sudo rm -rf -- "$PLY_DIR"
  sudo mkdir -p "$PLY_DIR"
  for f in logo.png progress-track.png progress-fill.png viskooos.script viskooos.plymouth; do
    sudo install -m 644 "$SRC/plymouth/$f" "$PLY_DIR/$f"
  done
  sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$PLY_FILE" 200
  sudo update-alternatives --set default.plymouth "$PLY_FILE"
  log "Recriando initramfs (pode demorar ~1 min)"
  sudo update-initramfs -u

  # 9b. Tela de login (GDM) com o mesmo arranjo de monitores do usuário.
  #     Sem isso, com 2 telas o GDM reorganiza os monitores do jeito padrão dele ao assumir
  #     a tela e o último quadro do boot "pula" para a direita segundos antes do login.
  if [ -s "$HOME/.config/monitors.xml" ]; then
    log "Copiando o arranjo de monitores para a tela de login (GDM)"
    for d in /etc/xdg /var/lib/gdm3/seat0/config /var/lib/gdm3/.config; do
      case "$d" in /var/lib/gdm3*) [ -d /var/lib/gdm3 ] || continue ;; esac
      [ -e "$d/monitors.xml" ] && [ ! -e "$d/monitors.xml.viskooos-orig" ] && sudo cp -a "$d/monitors.xml" "$d/monitors.xml.viskooos-orig"
      sudo install -D -m 644 "$HOME/.config/monitors.xml" "$d/monitors.xml"
      echo "$d/monitors.xml" >> "$STATE/gdm-monitors.list"
    done
    [ -d /var/lib/gdm3/.config ] && sudo chown -R gdm:gdm /var/lib/gdm3/.config 2>/dev/null || true
    sort -u -o "$STATE/gdm-monitors.list" "$STATE/gdm-monitors.list"
  fi
fi

sort -u -o "$MANIFEST" "$MANIFEST"
log "Concluído! Faça LOGOUT e LOGIN (Wayland) para o tema do Shell e o cursor aparecerem."
echo "Para desfazer tudo:  bash \"$ROOT/uninstall.sh\""
