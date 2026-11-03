echo "Vou instalar Spotify, Kdenlive, VLC, atom, slack, mailspring, inkscape, blender, obs, libre, krita, gimp, vectr"

echo "Atualizando tudo..."
sudo apt-get update
sudo apt-get upgrade

echo "Iniciando as instalações"
sudo snap install snap-store
sudo snap install spotify
sudo snap install kdenlive
sudo snap install vlc
sudo snap install atom --classic
sudo snap install slack --classic
sudo snap install mailspring
sudo snap install inkscape
sudo snap install blender --classic
sudo snap install obs-studio
sudo snap install libreoffice
sudo snap install krita
sudo snap install gimp
sudo snap install vectr

echo "Instalando FLATPAK"
sudo add-apt-repository ppa:alexlarsson/flatpak
sudo apt update
sudo apt install flatpak

echo "Instalando softwares do Flatpak"
flatpak install --user http://flatpak.pitivi.org/pitivi.flatpakref
flatpak install flathub org.filezillaproject.Filezilla

echo "Instale o Pingendo, VirtualBox, PlayOnLinux, TeamViewer se quiser =)"

