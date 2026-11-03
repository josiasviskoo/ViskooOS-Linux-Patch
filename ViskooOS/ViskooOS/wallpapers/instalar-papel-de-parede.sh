#!/usr/bin/env bash
# Instala os papéis de parede do Viskoo OS e define o padrão:
# motocicleta-custom-em-garagem-industrial.png
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
DEST=/usr/share/backgrounds/viskooos
PADRAO="file://$DEST/motocicleta-custom-em-garagem-industrial.png"

sudo install -d "$DEST"
sudo install -m 644 "$DIR"/*.png "$DEST"/
sudo install -Dm 644 "$DIR/viskooos-wallpapers.xml" /usr/share/gnome-background-properties/viskooos-wallpapers.xml
sudo install -m 644 "$DIR/90_viskooos-wallpaper.gschema.override" /usr/share/glib-2.0/schemas/
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/

# Aplica também ao usuário atual (novos usuários já recebem pelo override)
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  gsettings set org.gnome.desktop.background picture-uri "$PADRAO"
  gsettings set org.gnome.desktop.background picture-uri-dark "$PADRAO"
  gsettings set org.gnome.desktop.background picture-options zoom
  gsettings set org.gnome.desktop.screensaver picture-uri "$PADRAO"
fi
echo "Papel de parede padrão do Viskoo OS instalado."
