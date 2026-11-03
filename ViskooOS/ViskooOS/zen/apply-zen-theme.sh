#!/usr/bin/env bash
# ViskooOS — aplica o design do Zen Browser (cinza chumbo + barra de endereços no topo)
# em todos os perfis do Zen do usuário (Flatpak e instalação nativa).
# Roda como o USUÁRIO (não root). Seguro rodar várias vezes.
set -uo pipefail
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
FLAT_ID=app.zen_browser.zen
BASES=("$HOME/.var/app/$FLAT_ID/.zen" "$HOME/.zen")
MARK_A="// >>> ViskooOS >>>"; MARK_B="// <<< ViskooOS <<<"
STATE="$HOME/.local/share/viskooos"; mkdir -p "$STATE"

profiles() {   # caminhos absolutos dos perfis listados em profiles.ini
  local b
  for b in "${BASES[@]}"; do
    [ -f "$b/profiles.ini" ] || continue
    python3 -I - "$b" <<'PY'
import configparser, os, sys
b = sys.argv[1]; c = configparser.RawConfigParser(); c.optionxform = str
c.read(os.path.join(b, "profiles.ini"))
for s in c.sections():
    if c.has_option(s, "Path"):
        p = c.get(s, "Path")
        rel = c.get(s, "IsRelative", fallback="1") == "1"
        p = os.path.join(b, p) if rel else p
        if os.path.isdir(p): print(p)
PY
  done
}

# Zen nunca aberto? cria o perfil padrão abrindo-o uma vez em segundo plano (sem janela)
if [ -z "$(profiles)" ] && flatpak info "$FLAT_ID" >/dev/null 2>&1; then
  echo "Criando o perfil do Zen (primeira execução, sem janela)…"
  timeout 25 flatpak run "$FLAT_ID" --headless about:blank >/dev/null 2>&1 || true
fi

n=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  mkdir -p "$p/chrome"
  if [ -f "$p/chrome/userChrome.css" ] && ! grep -q "ViskooOS" "$p/chrome/userChrome.css"; then
    cp "$p/chrome/userChrome.css" "$p/chrome/userChrome.css.antes-viskooos"
  fi
  [ -e "$p/chrome/userChrome.css" ] || echo "$p/chrome/userChrome.css" >> "$STATE/files.manifest"
  cp "$HERE/userChrome.css" "$p/chrome/userChrome.css"
  # user.js: substitui só o bloco ViskooOS, preservando o que mais houver
  touch "$p/user.js"
  python3 -I - "$p/user.js" "$HERE/user.js" "$MARK_A" "$MARK_B" <<'PY'
import re, sys
dst, src, a, b = sys.argv[1:5]
old = open(dst).read()
old = re.sub(re.escape(a) + r".*?" + re.escape(b) + r"\n?", "", old, flags=re.S)
block = f"{a}\n{open(src).read().rstrip()}\n{b}\n"
open(dst, "w").write((old.rstrip() + "\n\n" if old.strip() else "") + block)
PY
  echo "✔ design ViskooOS aplicado no perfil: $p"
  n=$((n + 1))
done < <(profiles)
sort -u -o "$STATE/files.manifest" "$STATE/files.manifest" 2>/dev/null || true

if [ "$n" = 0 ]; then echo "Nenhum perfil do Zen encontrado — abra o Zen uma vez e rode de novo: bash \"$0\""; exit 1; fi
pgrep -f "$FLAT_ID|/zen-bin|/zen " >/dev/null && echo "O Zen está aberto: feche e abra de novo para ver o novo design."
exit 0
