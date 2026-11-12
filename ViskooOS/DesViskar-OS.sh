#!/usr/bin/env bash
# DesViskar OS — tira a marca Viskoo do sistema e mantém todo o resto do visual.
#
# REMOVE:   logo ViskooOS do dock (botão "Mostrar aplicativos"), da tela de LOGIN (GDM),
#           da tela de BOOT (Plymouth + marca d'água do tema reserva), de Configurações > Sobre,
#           dos pixmaps do sistema, do atalho de apps e os papéis de parede ViskooOS.
# TEXTO:    os temas "ViskooOS" (GTK, Shell, ícones e cursor) são renomeados (padrão: "Laranja"),
#           então o nome ViskooOS some de Configurações/Ajustes; o atalho vira "Instalar Apps".
# DEVOLVE:  logo oficial do Ubuntu em todos esses lugares e o papel de parede padrão do Ubuntu atual.
# MANTÉM:   efeitos Compiz e extensões, temas GTK/Shell, janelas e botões, dock flutuante,
#           ícones/pastas laranja, cursor, fontes, Kvantum, Plank, Zen Browser e os apps instalados.
#
# Uso:  bash DesViskar-OS.sh
#       NOVO_NOME=MeuTema bash DesViskar-OS.sh   (escolhe o novo nome dos temas)
# Para remover TUDO do ViskooOS (inclusive temas e efeitos):  bash uninstall.sh
set -uo pipefail

STATE="$HOME/.local/share/viskooos"
NOVO="${NOVO_NOME:-Laranja}"
UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
SCHEMADIR="/usr/share/gnome-shell/extensions/$UUID/schemas"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { echo "  ✔ $*"; }
warn() { echo "  ⚠ $*"; }

[ "$(id -u)" -ne 0 ] || { echo "Não rode como root; o script pede sudo quando precisa."; exit 1; }
if ! [[ "$NOVO" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "${NOVO,,}" == *viskoo* ]]; then
  echo "NOVO_NOME inválido: use só letras, números, ponto, hífen ou _ (e sem 'viskoo')."; exit 1
fi

echo "DesViskar OS: o logo e o nome ViskooOS serão removidos do boot, login, dock e sistema."
echo "Os temas passam a se chamar \"$NOVO\". Efeitos, janelas e o dock continuam como estão."
read -r -p "Continuar? [s/N] " r
[[ "$r" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 0; }
sudo -v || { echo "Senha não confirmada."; exit 1; }
mkdir -p "$STATE"

# gsettings da extensão User Themes (o schema pode não estar no caminho padrão)
ut() {
  if gsettings list-schemas | grep -qx org.gnome.shell.extensions.user-theme; then
    gsettings "$@"
  elif [ -d "$SCHEMADIR" ]; then
    gsettings --schemadir "$SCHEMADIR" "$@"
  else
    return 1
  fi
}

# tema de ícones atual (antes ou depois de já ter sido renomeado)
ICON_DIR="$HOME/.icons/ViskooOS"; [ -d "$ICON_DIR" ] || ICON_DIR="$HOME/.icons/$NOVO"
SHELL_CSS="$HOME/.themes/ViskooOS/gnome-shell/gnome-shell.css"
[ -f "$SHELL_CSS" ] || SHELL_CSS="$HOME/.themes/$NOVO/gnome-shell/gnome-shell.css"

# 1. Dock e ícones: tira os logos ViskooOS do tema de ícones (pastas laranja e cursor ficam).
#    Sem esses arquivos, o sistema usa os ícones do Yaru, que trazem o logo oficial do Ubuntu.
if [ -d "$ICON_DIR" ]; then
  log "Removendo o logo ViskooOS do dock e do tema de ícones"
  for f in \
    scalable/apps/{distributor-logo,start-here,ubuntu-logo,ubuntu-logo-dark,ubuntu-logo-icon,ubuntu-logo-text,ubuntu-logo-text-dark,viskooos}.svg \
    symbolic/actions/{distributor-logo,start-here,ubuntu-logo,ubuntu-logo-icon,view-app-grid,view-app-grid-ubuntu,view-app-grid-user,viskooos}-symbolic.svg; do
    [ -e "$ICON_DIR/$f" ] && rm -f -- "$ICON_DIR/$f" && ok "removido: $ICON_DIR/$f"
  done
  # herda o Yaru (tema oficial do Ubuntu) para encontrar os logos originais
  if [ -d /usr/share/icons/Yaru ] && ! grep -q '^Inherits=.*Yaru' "$ICON_DIR/index.theme"; then
    sed -i 's/^Inherits=.*/Inherits=Adwaita,Yaru,hicolor/' "$ICON_DIR/index.theme" && ok "tema de ícones agora herda o Yaru"
  fi
fi

# 1b. Tema do Shell: o botão "Mostrar aplicativos" volta à cor original (sem o laranja ViskooOS)
if [ -f "$SHELL_CSS" ] && grep -q 'logo ViskooOS em laranja' "$SHELL_CSS"; then
  sed -i '/Botão "Mostrar aplicativos" com o logo ViskooOS em laranja/d;
          /^\.show-apps \.show-apps-icon, \.show-apps \.overview-icon StIcon { color: #[0-9a-fA-F]*; }$/d' "$SHELL_CSS"
  ok "cor do botão \"Mostrar aplicativos\" restaurada no tema do Shell"
fi

# 1c. Texto "ViskooOS": renomeia os temas GTK/Shell/ícones/cursor e troca o nome nos arquivos
log "Tirando o nome ViskooOS dos temas (novo nome: $NOVO)"
for base in "$HOME/.themes" "$HOME/.icons"; do
  de="$base/ViskooOS"; para="$base/$NOVO"
  if [ -d "$de" ]; then
    if [ -e "$para" ]; then warn "$para já existe; mantendo $de (use NOVO_NOME=outro)"; continue; fi
    mv -- "$de" "$para" && ok "renomeado: $de → $para"
  fi
  # nomes e comentários dentro do tema (index.theme, cursor.theme, CSS)
  [ -d "$para" ] && grep -rlI 'ViskooOS' "$para" 2>/dev/null | while IFS= read -r f; do
    sed -i "s/ViskooOS/$NOVO/g" "$f"
  done
done
ICON_DIR="$HOME/.icons/$NOVO"
[ -f "$ICON_DIR/icon-theme.cache" ] && gtk-update-icon-cache -f -q "$ICON_DIR" 2>/dev/null
[ -d "$ICON_DIR" ] && touch "$ICON_DIR"
# cursor padrão do sistema (~/.icons/default) e CSS do libadwaita
[ -f "$HOME/.icons/default/index.theme" ] && sed -i "s/^Inherits=ViskooOS\$/Inherits=$NOVO/" "$HOME/.icons/default/index.theme"
[ -f "$HOME/.config/gtk-4.0/gtk.css" ] && sed -i "s/ViskooOS/$NOVO/g" "$HOME/.config/gtk-4.0/gtk.css"
# aplica os temas com o novo nome
for k in gtk-theme icon-theme cursor-theme; do
  [ "$(gsettings get org.gnome.desktop.interface "$k")" = "'ViskooOS'" ] &&
    gsettings set org.gnome.desktop.interface "$k" "$NOVO" && ok "$k = $NOVO"
done
if [ "$(ut get org.gnome.shell.extensions.user-theme name 2>/dev/null)" = "'ViskooOS'" ]; then
  ut set org.gnome.shell.extensions.user-theme name "$NOVO" && ok "tema do Shell = $NOVO"
fi
# o uninstall.sh continua achando os arquivos renomeados
[ -f "$STATE/files.manifest" ] &&
  sed -i -E "s#/(\.themes|\.icons)/ViskooOS(/|\$)#/\1/$NOVO\2#" "$STATE/files.manifest"

# 2. Logos do sistema: tela de LOGIN (GDM usa /usr/share/pixmaps/ubuntu-logo-text-dark.svg),
#    Configurações > Sobre e a marca d'água do boot (spinner/bgrt). Devolve os originais (dpkg-divert).
#    LC_ALL=C: em português o dpkg-divert escreve "desvio de ... por viskooos" em vez de "by viskooos".
KNOWN_DIVS=(
  /usr/share/pixmaps/ubuntu-logo.svg
  /usr/share/pixmaps/ubuntu-logo-text.svg
  /usr/share/pixmaps/ubuntu-logo-text.png
  /usr/share/pixmaps/ubuntu-logo-text-dark.svg
  /usr/share/pixmaps/ubuntu-logo-text-dark.png
  /usr/share/plymouth/themes/spinner/watermark.png
  /usr/share/plymouth/themes/spinner/bgrt-fallback.png
)
divs="$( {
  LC_ALL=C dpkg-divert --list 2>/dev/null | awk '$NF == "viskooos" {print $3}'
  for f in "${KNOWN_DIVS[@]}"; do
    [ "$(dpkg-divert --listpackage "$f" 2>/dev/null)" = viskooos ] && echo "$f"
  done
} | sort -u)"
reinstall=()
if [ -n "$divs" ]; then
  log "Devolvendo os logos originais do Ubuntu (login, boot e Configurações)"
  while IFS= read -r dst; do
    [ -n "$dst" ] || continue
    sudo rm -f -- "$dst"
    if sudo dpkg-divert --package viskooos --rename --remove "$dst" >/dev/null; then
      ok "restaurado: $dst"
    else
      warn "não consegui remover o desvio de $dst"
    fi
    # sem o original guardado (.ubuntu), reinstala o pacote dono do arquivo
    if [ ! -e "$dst" ]; then
      pkg="$(dpkg-query -S "$dst" 2>/dev/null | head -1 | cut -d: -f1)"
      [ -n "$pkg" ] && reinstall+=("$pkg")
    fi
  done <<< "$divs"
  if [ ${#reinstall[@]} -gt 0 ]; then
    mapfile -t reinstall < <(printf '%s\n' "${reinstall[@]}" | sort -u)
    log "Reinstalando pacotes para recuperar logos originais: ${reinstall[*]}"
    sudo apt-get install -y --reinstall "${reinstall[@]}"
  fi
fi

# 2b. Tela de login: remove qualquer logo personalizado que aponte para arquivos ViskooOS
for f in /etc/gdm3/greeter.dconf-defaults /etc/dconf/db/gdm.d/*; do
  [ -f "$f" ] && grep -qi '^logo=.*viskoo' "$f" || continue
  sudo sed -i '/^logo=.*[vV]iskoo/d' "$f" && ok "logo ViskooOS removido de $f"
  sudo dconf update 2>/dev/null || true
done
if sudo test -f /var/lib/gdm3/.config/dconf/user && sudo grep -qai 'viskoo' /var/lib/gdm3/.config/dconf/user; then
  sudo -u gdm dbus-run-session -- gsettings reset org.gnome.login-screen logo 2>/dev/null &&
    ok "logo da tela de login resetado nas configurações do GDM"
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
  need_initramfs=1
fi
# configuração manual do Plymouth apontando para o tema ViskooOS
if [ -f /etc/plymouth/plymouthd.conf ] && grep -qi '^Theme=viskooos' /etc/plymouth/plymouthd.conf; then
  sudo sed -i '/^Theme=[vV]iskooos/d' /etc/plymouth/plymouthd.conf && ok "Theme=viskooos removido de /etc/plymouth/plymouthd.conf"
  need_initramfs=1
fi
cur_ply="$(update-alternatives --query default.plymouth 2>/dev/null | awk '/^Value:/{print $2}')"
[ -n "$cur_ply" ] && ok "tema de boot: $cur_ply"

# as imagens do boot ficam dentro do initramfs: recria se algo mudou ou se ele ainda tem ViskooOS
INITRD="/boot/initrd.img-$(uname -r)"
if [ "$need_initramfs" = 0 ] && [ -n "$divs" ]; then need_initramfs=1; fi
if [ "$need_initramfs" = 0 ] && [ -f "$INITRD" ] && sudo lsinitramfs "$INITRD" 2>/dev/null | grep -qi viskoo; then
  need_initramfs=1
fi
if [ "$need_initramfs" = 1 ]; then
  log "Recriando initramfs (pode demorar ~1 min)"
  sudo update-initramfs -u -k all
  if [ -f "$INITRD" ] && sudo lsinitramfs "$INITRD" 2>/dev/null | grep -qi viskoo; then
    warn "o initramfs ainda contém arquivos ViskooOS — confira com: sudo lsinitramfs $INITRD | grep -i viskoo"
  else
    ok "initramfs sem ViskooOS"
  fi
fi
# o arranjo de monitores na tela de login (GDM) é mantido: não é marca, evita o "pulo" da imagem no boot

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

# 6. Atalho de apps no menu: sem logo e sem o nome ViskooOS.
#    A marca "sem-marca" faz o install-apps.sh / viskooos-apps.py manterem isso nas próximas execuções.
touch "$STATE/sem-marca"
DESK="$HOME/.local/share/applications/viskooos-apps.desktop"
if [ -f "$DESK" ]; then
  sed -i 's|^Icon=.*|Icon=system-software-install|; s|^Name=.*|Name=Instalar Apps|' "$DESK" &&
    ok "atalho do menu: \"Instalar Apps\" com ícone genérico"
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# 7. Conferência final: o que ainda tem ViskooOS visível
log "Conferindo"
left=0
for f in /usr/share/pixmaps/ubuntu-logo-text-dark.svg /usr/share/plymouth/themes/spinner/watermark.png; do
  if [ "$(dpkg-divert --listpackage "$f" 2>/dev/null)" = viskooos ]; then warn "ainda desviado: $f"; left=1; fi
done
[ -d "$PLY_DIR" ] && { warn "ainda existe: $PLY_DIR"; left=1; }
for k in gtk-theme icon-theme cursor-theme; do
  v="$(gsettings get org.gnome.desktop.interface "$k")"
  [[ "$v" == *[vV]iskoo* ]] && { warn "$k ainda é $v"; left=1; }
done
[ "$left" = 0 ] && ok "nenhum logo ou nome ViskooOS restante no boot, login, dock e temas"

log "Pronto! Faça LOGOUT e LOGIN para o dock, o Shell e os temas renomeados aparecerem."
echo "O logo do Ubuntu volta na tela de login e na tela de boot na próxima reinicialização."
echo "Obs.: rodar o install.sh de novo traz o logo, o nome e os papéis de parede ViskooOS de volta."
