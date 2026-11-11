#!/usr/bin/env bash
# DesViskar OS — tira a marca Viskoo do sistema e mantém todo o resto do visual.
#
# REMOVE:   logo ViskooOS do dock (botão "Mostrar aplicativos"), logos em Configurações > Sobre,
#           logo da tela de boot (Plymouth), pixmaps do sistema e os papéis de parede ViskooOS.
# DEVOLVE:  logo oficial do Ubuntu em todos esses lugares e o papel de parede padrão do Ubuntu atual.
# MANTÉM:   efeitos Compiz e extensões, temas GTK/Shell, janelas e botões, dock flutuante,
#           ícones/pastas laranja, cursor, fontes, Kvantum, Plank, Zen Browser e os apps instalados.
#
# Uso:  bash DesViskar-OS.sh
# Para remover TUDO do ViskooOS (inclusive temas e efeitos):  bash uninstall.sh
set -uo pipefail

STATE="$HOME/.local/share/viskooos"
ICON_DIR="$HOME/.icons/ViskooOS"
SHELL_CSS="$HOME/.themes/ViskooOS/gnome-shell/gnome-shell.css"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { echo "  ✔ $*"; }

[ "$(id -u)" -ne 0 ] || { echo "Não rode como root; o script pede sudo quando precisa."; exit 1; }

echo "DesViskar OS: os logos e papéis de parede ViskooOS serão removidos."
echo "Os efeitos, temas, janelas e o dock continuam como estão."
read -r -p "Continuar? [s/N] " r
[[ "$r" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }
sudo -v || { echo "Senha não confirmada."; exit 1; }

# 1. Dock e ícones: tira os logos ViskooOS do tema de ícones (pastas laranja e cursor ficam).
#    Sem esses arquivos, o sistema usa os ícones do Yaru, que trazem o logo oficial do Ubuntu.
if [ -d "$ICON_DIR" ]; then
  log "Removendo o logo ViskooOS do dock e do tema de ícones"
  for f in \
    scalable/apps/{distributor-logo,start-here,ubuntu-logo,ubuntu-logo-dark,ubuntu-logo-icon,ubuntu-logo-text,ubuntu-logo-text-dark,viskooos}.svg \
    symbolic/actions/{distributor-logo,start-here,ubuntu-logo,ubuntu-logo-icon,view-app-grid,view-app-grid-ubuntu,view-app-grid-user,viskooos}-symbolic.svg; do
    [ -e "$ICON_DIR/$f" ] && rm -f -- "$ICON_DIR/$f" && ok "removido: ~/.icons/ViskooOS/$f"
  done
  # herda o Yaru (tema oficial do Ubuntu) para encontrar os logos originais
  if [ -d /usr/share/icons/Yaru ] && ! grep -q '^Inherits=.*Yaru' "$ICON_DIR/index.theme"; then
    sed -i 's/^Inherits=.*/Inherits=Adwaita,Yaru,hicolor/' "$ICON_DIR/index.theme" && ok "tema de ícones agora herda o Yaru"
  fi
  [ -f "$ICON_DIR/icon-theme.cache" ] && gtk-update-icon-cache -f -q "$ICON_DIR" 2>/dev/null
  touch "$ICON_DIR"
fi

# 1b. Tema do Shell: o botão "Mostrar aplicativos" volta à cor original (sem o laranja ViskooOS)
if [ -f "$SHELL_CSS" ] && grep -q 'logo ViskooOS em laranja' "$SHELL_CSS"; then
  sed -i '/Botão "Mostrar aplicativos" com o logo ViskooOS em laranja/d;
          /^\.show-apps \.show-apps-icon, \.show-apps \.overview-icon StIcon { color: #[0-9a-fA-F]*; }$/d' "$SHELL_CSS"
  ok "cor do botão \"Mostrar aplicativos\" restaurada no tema do Shell"
fi

# 2. Logos do sistema (Configurações > Sobre, tela de boot reserva): devolve os originais (dpkg-divert)
divs="$(dpkg-divert --list 2>/dev/null | awk '/by viskooos$/{print $3}')"
if [ -n "$divs" ]; then
  log "Devolvendo os logos originais do Ubuntu"
  for dst in $divs; do
    sudo rm -f -- "$dst"
    sudo dpkg-divert --package viskooos --rename --remove "$dst" >/dev/null && ok "restaurado: $dst"
  done
fi

# 3. Tela de boot (Plymouth): volta para o tema oficial do Ubuntu
PLY_DIR="/usr/share/plymouth/themes/viskooos"
need_initramfs=0
if [ -d "$PLY_DIR" ] || update-alternatives --query default.plymouth 2>/dev/null | grep -q "$PLY_DIR"; then
  log "Restaurando a tela de boot oficial do Ubuntu"
  sudo update-alternatives --remove default.plymouth "$PLY_DIR/viskooos.plymouth" >/dev/null 2>&1 || true
  prev=""
  [ -s "$STATE/plymouth.previous" ] && prev="$(cat "$STATE/plymouth.previous")"
  if [ -n "$prev" ] && [ -f "$prev" ] && [[ "$prev" != *viskooos* ]]; then
    sudo update-alternatives --set default.plymouth "$prev"
  else
    sudo update-alternatives --auto default.plymouth
  fi
  sudo rm -rf -- "$PLY_DIR"
  ok "tema de boot: $(update-alternatives --query default.plymouth | awk '/^Value:/{print $2}')"
  need_initramfs=1
fi
# o arranjo de monitores na tela de login (GDM) é mantido: não é marca, evita o "pulo" da imagem no boot
if [ "$need_initramfs" = 1 ] || [ -n "$divs" ]; then   # as imagens do boot ficam dentro do initramfs
  log "Recriando initramfs (pode demorar ~1 min)"
  sudo update-initramfs -u
fi

# 4. Papéis de parede ViskooOS
log "Removendo os papéis de parede ViskooOS"
for p in "$HOME/.local/share/backgrounds/viskooos" \
         "$HOME/.local/share/gnome-background-properties/viskooos.xml"; do
  [ -e "$p" ] && rm -rf -- "$p" && ok "removido: $p"
done
rmdir "$HOME/.local/share/backgrounds" "$HOME/.local/share/gnome-background-properties" 2>/dev/null || true
# versão instalada no sistema por ViskooOS/wallpapers/instalar-papel-de-parede.sh
recompile=0
for p in /usr/share/backgrounds/viskooos \
         /usr/share/gnome-background-properties/viskooos-wallpapers.xml \
         /usr/share/glib-2.0/schemas/90_viskooos-wallpaper.gschema.override; do
  if [ -e "$p" ]; then
    sudo rm -rf -- "$p" && ok "removido: $p"
    [[ "$p" == *.gschema.override ]] && recompile=1
  fi
done
[ "$recompile" = 1 ] && sudo glib-compile-schemas /usr/share/glib-2.0/schemas/

# 5. Papel de parede padrão do Ubuntu atual (o que a própria versão do Ubuntu define)
log "Aplicando o papel de parede padrão do Ubuntu"
for k in picture-uri picture-uri-dark picture-options primary-color secondary-color; do
  gsettings reset org.gnome.desktop.background "$k" 2>/dev/null || true
done
gsettings reset org.gnome.desktop.screensaver picture-uri 2>/dev/null || true
ok "claro: $(gsettings get org.gnome.desktop.background picture-uri)"
ok "escuro: $(gsettings get org.gnome.desktop.background picture-uri-dark)"
# o backup do uninstall.sh também passa a apontar para o padrão (os arquivos ViskooOS não existem mais)
[ -f "$STATE/gsettings.backup" ] && sed -i '/viskooos/{/picture-uri/d}' "$STATE/gsettings.backup"

# 6. Atalho "ViskooOS Apps" no menu: troca o logo ViskooOS por um ícone genérico
DESK="$HOME/.local/share/applications/viskooos-apps.desktop"
if [ -f "$DESK" ] && grep -q '^Icon=.*plymouth/logo.png' "$DESK"; then
  sed -i 's|^Icon=.*|Icon=system-software-install|' "$DESK" && ok "ícone do atalho ViskooOS Apps trocado"
fi

log "Pronto! Faça LOGOUT e LOGIN para o dock e o Shell mostrarem o logo do Ubuntu."
echo "A nova tela de boot aparece na próxima reinicialização."
echo "Obs.: rodar o install.sh de novo traz o logo e os papéis de parede ViskooOS de volta."
