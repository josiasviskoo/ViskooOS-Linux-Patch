#!/usr/bin/env bash
# ViskooOS — desinstalador: volta o Ubuntu como estava antes do install.sh
# Uso:  bash uninstall.sh            (pergunta se remove os pacotes apt)
#       REMOVE_APT=1 bash uninstall.sh   (remove os pacotes sem perguntar)
#       REMOVE_APT=0 bash uninstall.sh   (mantém os pacotes)
set -uo pipefail

UUID="user-theme@gnome-shell-extensions.gcampax.github.com"
STATE="$HOME/.local/share/viskooos"
BACKUP="$STATE/gsettings.backup"
MANIFEST="$STATE/files.manifest"
PKGS_NEW="$STATE/packages.new"
SCHEMADIR="/usr/share/gnome-shell/extensions/$UUID/schemas"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
[ "$(id -u)" -ne 0 ] || { echo "Não rode como root."; exit 1; }

ut() {
  if gsettings list-schemas | grep -qx org.gnome.shell.extensions.user-theme; then
    gsettings "$@"
  elif [ -d "$SCHEMADIR" ]; then
    gsettings --schemadir "$SCHEMADIR" "$@"
  else
    return 1
  fi
}

# 1. Configurações: restaura o backup; sem backup, volta ao padrão do Ubuntu
if [ -s "$BACKUP" ]; then
  log "Restaurando configurações originais"
  while IFS='|' read -r schema key value; do
    [ -n "$schema" ] || continue
    if [ "$schema" = "org.gnome.shell.extensions.user-theme" ]; then
      ut set "$schema" "$key" "$value" 2>/dev/null || true
    else
      gsettings set "$schema" "$key" "$value" || echo "  aviso: não consegui restaurar $schema $key"
    fi
  done < "$BACKUP"
  # backups antigos não guardavam a posição dos botões da janela
  grep -q '^org.gnome.desktop.wm.preferences|button-layout|' "$BACKUP" || gsettings reset org.gnome.desktop.wm.preferences button-layout
else
  log "Backup não encontrado — voltando ao padrão do Ubuntu"
  for k in gtk-theme icon-theme cursor-theme color-scheme accent-color; do gsettings reset org.gnome.desktop.interface "$k"; done
  for k in picture-uri picture-uri-dark picture-options; do gsettings reset org.gnome.desktop.background "$k"; done
  gsettings reset org.gnome.desktop.screensaver picture-uri
  gsettings reset org.gnome.desktop.wm.preferences button-layout
  gsettings reset-recursively org.gnome.shell.extensions.dash-to-dock 2>/dev/null || true
  ut reset org.gnome.shell.extensions.user-theme name 2>/dev/null || true
  cur="$(gsettings get org.gnome.shell enabled-extensions)"
  new="$(printf '%s' "$cur" | sed -E "s/, *'$UUID'//; s/'$UUID', *//; s/'$UUID'//")"
  gsettings set org.gnome.shell enabled-extensions "$new"
fi

# 2. Arquivos copiados pelo instalador (só os que ele criou)
if [ -s "$MANIFEST" ]; then
  log "Removendo arquivos instalados"
  # ordem reversa: conteúdo antes das pastas-pai
  sort -r "$MANIFEST" | while IFS= read -r p; do
    case "$p" in "$HOME"/?*) ;; *) echo "  ignorado (fora do HOME): $p"; continue ;; esac
    [ -e "$p" ] || continue
    if [ -d "$p" ] && [[ "$p" =~ /(\.themes|\.icons|Kvantum|plank|themes|backgrounds|gnome-background-properties)$ ]]; then
      rmdir "$p" 2>/dev/null && echo "  pasta vazia removida: $p" || echo "  mantida (tem outros arquivos): $p"
    else
      rm -rf -- "$p" && echo "  removido: $p"
    fi
  done
else
  log "Manifesto não encontrado — nada de arquivos para remover automaticamente"
  echo "  Remova manualmente, se quiser: ~/.themes ~/.icons ~/.config/Kvantum ~/.local/share/backgrounds/viskooos ~/.local/share/gnome-background-properties/viskooos.xml"
fi

# 2b. CSS do libadwaita: devolve o arquivo que existia antes (se havia)
if [ -s "$STATE/gtk4.css.orig" ]; then
  mkdir -p "$HOME/.config/gtk-4.0"
  cp -a "$STATE/gtk4.css.orig" "$HOME/.config/gtk-4.0/gtk.css" && echo "  restaurado: ~/.config/gtk-4.0/gtk.css"
fi

# 3. Tela de boot (Plymouth): volta ao tema anterior
PLY_DIR="/usr/share/plymouth/themes/viskooos"
if [ -d "$PLY_DIR" ]; then
  log "Restaurando a tela de boot original"
  prev=""
  [ -s "$STATE/plymouth.previous" ] && prev="$(cat "$STATE/plymouth.previous")"
  sudo update-alternatives --remove default.plymouth "$PLY_DIR/viskooos.plymouth" || true
  if [ -n "$prev" ] && [ -f "$prev" ]; then
    sudo update-alternatives --set default.plymouth "$prev"
  else
    sudo update-alternatives --auto default.plymouth
  fi
  sudo rm -rf -- "$PLY_DIR"
  log "Recriando initramfs (pode demorar ~1 min)"
  sudo update-initramfs -u
fi

# 3b. Logos do Ubuntu: remove os arquivos ViskooOS e devolve os originais (dpkg-divert)
divs="$(dpkg-divert --list 2>/dev/null | awk '/by viskooos$/{print $3}')"
if [ -n "$divs" ]; then
  log "Devolvendo os logos originais do Ubuntu"
  for dst in $divs; do
    sudo rm -f -- "$dst"
    sudo dpkg-divert --package viskooos --rename --remove "$dst" >/dev/null && echo "  restaurado: $dst"
  done
fi

# 4. Pacotes apt que o instalador adicionou
if [ -s "$PKGS_NEW" ]; then
  mapfile -t pkgs < "$PKGS_NEW"
  ans="${REMOVE_APT:-}"
  if [ -z "$ans" ]; then
    read -r -p "Remover os pacotes instalados pelo ViskooOS (${pkgs[*]})? [s/N] " r
    [[ "$r" =~ ^[sSyY]$ ]] && ans=1 || ans=0
  fi
  if [ "$ans" = "1" ]; then
    log "Removendo pacotes: ${pkgs[*]}"
    sudo apt remove -y "${pkgs[@]}" && sudo apt autoremove -y
  else
    echo "Pacotes mantidos."
  fi
fi

rm -rf -- "$STATE"
log "Pronto! Faça LOGOUT e LOGIN para o visual original voltar por completo."
