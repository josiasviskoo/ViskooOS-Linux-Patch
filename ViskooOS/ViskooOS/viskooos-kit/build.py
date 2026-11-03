#!/usr/bin/env python3
"""
ViskooOS — gerador do kit visual (tema GTK, Shell, ícones e cursor).

Gera, a partir dos temas que o Josias escolheu como base, versões
"ViskooOS" em modo escuro com detalhes laranja:

  Aplicativos legados (GTK3/GTK4) : Yaru-dark            -> _.themes/ViskooOS/gtk-3.0, gtk-4.0
  Shell (painel, menus, dock)     : Yaru-dark (Shell)    -> _.themes/ViskooOS/gnome-shell
  Ícones                          : Adwaita (pastas)     -> _.icons/ViskooOS (herda Adwaita)
  Cursor                          : DMZ-Black            -> _.icons/ViskooOS/cursors
  Botão "Mostrar aplicativos"     : logo ViskooOS        -> view-app-grid-*-symbolic (60% do tamanho)
  Logos do Ubuntu -> ViskooOS     : ícones ubuntu-logo*, distributor-logo, start-here (Configurações > Sobre)
                                    + ViskooOS/branding (pixmaps do sistema e tema de boot reserva)
  Apps modernos (libadwaita)      : gtk-4.0/libadwaita.css (instalado em ~/.config/gtk-4.0/gtk.css)

Uso:  python3 -I build.py          (rodar no Ubuntu, precisa do Yaru/Adwaita/DMZ do sistema)
      python3 -I build.py icons branding   (só refaz ícones/logos, sem mexer no GTK/Shell/cursor)
Para mudar o laranja, altere ACCENT_HUE / ACCENT abaixo e rode de novo.
"""
import base64, colorsys, io, os, re, shutil, struct, subprocess, sys
from pathlib import Path

from PIL import Image

KIT = Path(__file__).resolve().parent
SRC = KIT.parent                                   # pasta ViskooOS/ViskooOS
THEME = SRC / "_.themes" / "ViskooOS"
ICONS = SRC / "_.icons" / "ViskooOS"

ACCENT_HUE = 24 / 360          # laranja ViskooOS
ACCENT = "#ea7320"             # cor de destaque principal
ACCENT_LIGHT = "#f59a52"
ACCENT_DARK = "#b9561a"

YARU_DARK = Path("/usr/share/themes/Yaru-dark")
SHELL_BASE = Path("/usr/share/gnome-shell/theme/Yaru-dark")   # mesmo conteúdo de /usr/share/themes/Yaru-dark/gnome-shell
ADWAITA = Path("/usr/share/icons/Adwaita")
DMZ = Path("/usr/share/icons/DMZ-Black/cursors")
LOGO = SRC / "plymouth" / "logo.png"
BRANDING = SRC / "branding"
FONT = Path("/usr/share/fonts/truetype/ubuntu/UbuntuSans[wdth,wght].ttf")
# Botões da janela: fundos nas cores do macOS (fechar, minimizar, maximizar)
BTN_CLOSE, BTN_MIN, BTN_MAX = "#ff5f57", "#febc2e", "#28c840"
DOCK_LOGO_SCALE = 0.6          # logo do botão "Mostrar aplicativos" do dock: 40% menor


# ---------------------------------------------------------------- cores
def hue_in(h, ranges):
    d = h * 360
    return any(a <= d <= b for a, b in ranges)


def make_mapper(src_hues, min_sat=0.3, darken_greys=1.0, light_cap=None):
    """Retorna f(r,g,b)->(r,g,b): troca o matiz de destaque pelo laranja e escurece cinzas."""
    def f(r, g, b):
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if s >= min_sat and hue_in(h, src_hues) and 0.08 < l < 0.97:
            s = max(s, 0.82)
            if light_cap and l > 0.45:          # tons claros ficam mais "laranja" e menos pêssego
                l = 0.45 + (l - 0.45) * light_cap
            r2, g2, b2 = colorsys.hls_to_rgb(ACCENT_HUE, l, s)
        elif darken_greys != 1.0 and s < 0.08 and l < 0.30:
            r2, g2, b2 = colorsys.hls_to_rgb(h, l * darken_greys, s)
        else:
            return r, g, b
        return round(r2 * 255), round(g2 * 255), round(b2 * 255)
    return f


HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")
RGB = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*[\d.]+\s*)?\)")


def recolor_text(text, fn):
    def hx(m):
        v = m.group(1)
        if len(v) == 3:
            v = "".join(c * 2 for c in v)
        r, g, b = (int(v[i:i + 2], 16) for i in (0, 2, 4))
        n = fn(r, g, b)
        return m.group(0) if n == (r, g, b) else "#%02x%02x%02x" % n

    def rgb(m):
        r, g, b = (int(m.group(i)) for i in (1, 2, 3))
        n = fn(r, g, b)
        if n == (r, g, b):
            return m.group(0)
        a = m.group(4)
        return ("rgba(%d, %d, %d%s)" % (*n, a)) if a else ("rgb(%d, %d, %d)" % n)

    return RGB.sub(rgb, HEX.sub(hx, text))


def recolor_png(data, fn):
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = (r, g, b)
            if k not in cache:
                cache[k] = fn(r, g, b)
            px[x, y] = (*cache[k], a)
    out = io.BytesIO()
    im.save(out, "PNG")
    return out.getvalue()


# ---------------------------------------------------------------- GTK
def build_gtk():
    fn = make_mapper([(5, 32)], min_sat=0.4, darken_greys=0.85)   # laranja Yaru -> laranja ViskooOS
    for ver in ("3.0", "4.0"):
        res = YARU_DARK / f"gtk-{ver}" / "gtk.gresource"
        prefix = f"/com/ubuntu/themes/Yaru-dark/{ver}/"
        dest = THEME / f"gtk-{ver}"
        shutil.rmtree(dest, ignore_errors=True)
        names = subprocess.run(["gresource", "list", str(res)], check=True,
                               capture_output=True, text=True).stdout.split()
        for name in names:
            data = subprocess.run(["gresource", "extract", str(res), name],
                                  check=True, capture_output=True).stdout
            out = dest / name[len(prefix):]
            out.parent.mkdir(parents=True, exist_ok=True)
            if name.endswith((".css", ".svg")):
                data = recolor_text(data.decode(), fn).encode()
            elif name.endswith(".png"):
                data = recolor_png(data, fn)
            out.write_bytes(data)
        for c in ("gtk.css", "gtk-dark.css"):
            css = dest / c
            css.write_text("/* ViskooOS — gerado por viskooos-kit/build.py a partir do Yaru-dark */\n"
                           + css.read_text() + titlebutton_css(ver == "3.0"))
    # apps modernos (libadwaita) não usam o tema GTK: este arquivo vai para ~/.config/gtk-4.0/gtk.css
    (THEME / "gtk-4.0" / "libadwaita.css").write_text(f"""/* ViskooOS (libadwaita) — instalado pelo install.sh */
:root {{
  --accent-bg-color: {ACCENT};
  --accent-color: {ACCENT_LIGHT};
  --accent-fg-color: #ffffff;
  --window-bg-color: #1a1a1a;
  --view-bg-color: #141414;
  --headerbar-bg-color: #202020;
  --headerbar-backdrop-color: #1a1a1a;
  --sidebar-bg-color: #1e1e1e;
  --sidebar-backdrop-color: #1a1a1a;
  --secondary-sidebar-bg-color: #191919;
  --card-bg-color: rgb(255 255 255 / 5%);
  --dialog-bg-color: #222222;
  --popover-bg-color: #262626;
}}
@define-color accent_bg_color {ACCENT};
@define-color accent_color {ACCENT_LIGHT};
@define-color accent_fg_color #ffffff;
""" + titlebutton_css(False))


def titlebutton_css(gtk3):
    """Fundos dos botões fechar/minimizar/maximizar nas cores do macOS (bolinhas, com o ícone no centro)."""
    # GTK3: o fundo fica no próprio botão; GTK4/libadwaita: no ícone dentro de windowcontrols
    sel = ("headerbar button.titlebutton.{0}, .titlebar button.titlebutton.{0}" if gtk3
           else "windowcontrols > button.{0} > image")
    btn = ("headerbar button.titlebutton, .titlebar button.titlebutton" if gtk3
           else "windowcontrols > button")
    out = ["\n/* ViskooOS: botões da janela com fundos nas cores do macOS */"]
    if not gtk3:
        out.append(f"{btn}, {btn}:hover, {btn}:active, {btn}:backdrop "
                   "{ background: none; box-shadow: none; }")
    for cls, color in (("close", BTN_CLOSE), ("minimize", BTN_MIN), ("maximize", BTN_MAX)):
        s = sel.format(cls)
        hov = ", ".join(x.replace(f".{cls}", f".{cls}:hover") if gtk3 else x.replace(f".{cls} >", f".{cls}:hover >")
                        for x in s.split(", "))
        act = hov.replace(":hover", ":active")
        bd = hov.replace(":hover", ":backdrop")
        out.append(f"{s} {{ background-color: {color}; background-image: none; color: rgba(0, 0, 0, 0.65);"
                   " border-radius: 9999px; box-shadow: none; border: none; }")
        out.append(f"{hov} {{ background-color: shade({color}, 1.12); }}")
        out.append(f"{act} {{ background-color: shade({color}, 0.85); }}")
        out.append(f"{bd} {{ background-color: alpha({color}, 0.6); color: rgba(0, 0, 0, 0.5); }}")
    if not gtk3:
        out.append("windowcontrols > button > image { padding: 3px; }")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- Shell
SHELL_EXTRA = f"""
/* =================== ViskooOS: ajustes sobre o Yaru-dark =================== */
/* Dock (Ubuntu Dock) flutuante com cantos bem arredondados */
#dashtodockContainer #dash .dash-background {{
  background-color: rgba(18, 18, 18, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 24px;
}}
#dashtodockContainer.extended #dash .dash-background {{ border-radius: 0; }}

/* Botão "Mostrar aplicativos" com o logo ViskooOS em laranja */
.show-apps .show-apps-icon, .show-apps .overview-icon StIcon {{ color: {ACCENT}; }}

/* Campos de texto arredondados (busca, senha, login, diálogos) */
StEntry {{ border-radius: 12px; }}
StEntry:focus {{ border-color: {ACCENT}; }}
#searchEntry, .search-entry, .login-dialog StEntry, .unlock-dialog StEntry {{ border-radius: 999px; }}
.modal-dialog, .end-session-dialog, .prompt-dialog {{ border-radius: 18px; }}
.popup-menu-content, .candidate-popup-content {{ border-radius: 14px; }}
"""


def build_shell():
    """Cópia do Shell Yaru-dark do sistema, com o laranja ViskooOS fixo (não depende da cor de destaque)."""
    fn = make_mapper([(5, 32)], min_sat=0.4)            # laranjas do Yaru -> laranja ViskooOS
    dest = THEME / "gnome-shell"
    shutil.rmtree(dest, ignore_errors=True)
    shutil.copytree(SHELL_BASE, dest)
    for f in dest.rglob("*"):
        if f.suffix in (".css", ".svg"):
            t = recolor_text(f.read_text(), fn)
            if f.suffix == ".css":
                # cor de destaque do sistema -> laranja ViskooOS
                t = t.replace("-st-accent-fg-color", "#ffffff").replace("-st-accent-color", ACCENT)
                # imagens do tema embutido do Shell -> cópias locais (funciona mesmo sem o Yaru do sistema)
                t = t.replace("resource:///org/gnome/shell/theme/", "./")
            f.write_text(t)
    css = dest / "gnome-shell.css"
    css.write_text("/* ViskooOS — gerado por viskooos-kit/build.py a partir do Shell Yaru-dark */\n"
                   + css.read_text() + SHELL_EXTRA)


def build_theme_index():
    (THEME / "index.theme").write_text("""[Desktop Entry]
Type=X-GNOME-Metatheme
Name=ViskooOS
Comment=ViskooOS — modo escuro com detalhes laranja
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=ViskooOS
IconTheme=ViskooOS
CursorTheme=ViskooOS
ButtonLayout=close,minimize,maximize:
""")


# ---------------------------------------------------------------- Ícones
def logo_image(color):
    """Logo ViskooOS (PNG do Plymouth) recortado, quadrado e tingido com `color`."""
    im = Image.open(LOGO).convert("RGBA")
    im = im.crop(im.getbbox())
    side = max(im.size)
    sq = Image.new("RGBA", (side, side))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    r, g, b = (int(color[i:i + 2], 16) for i in (1, 3, 5))
    tinted = Image.new("RGBA", sq.size, (r, g, b, 255))
    tinted.putalpha(sq.getchannel("A"))
    return tinted


def png_b64(im):
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def logo_svg(color, size=14.0, canvas=16):
    """SVG com o logo ViskooOS embutido, ocupando `size` de um quadro `canvas`x`canvas`, centralizado."""
    b64 = png_b64(logo_image(color))
    o = (canvas - size) / 2
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{canvas}" height="{canvas}" viewBox="0 0 {canvas} {canvas}">'
            f'<image x="{o:g}" y="{o:g}" width="{size:g}" height="{size:g}" '
            f'xlink:href="data:image/png;base64,{b64}"/></svg>\n')


def wordmark_image(text_color, logo_color=ACCENT, height=288):
    """Logo + texto "ViskooOS" lado a lado (substitui o "ubuntu-logo-text"), proporção ~2,6:1."""
    from PIL import ImageDraw, ImageFont
    logo = logo_image(logo_color).resize((round(height * 0.78),) * 2, Image.LANCZOS)
    font = ImageFont.truetype(str(FONT), round(height * 0.42))
    try:
        font.set_variation_by_name("Medium")
    except Exception:
        pass
    text = "ViskooOS"
    l, t, r, b = font.getbbox(text)
    gap = round(height * 0.12)
    w = logo.width + gap + (r - l)
    im = Image.new("RGBA", (w, height))
    im.paste(logo, (0, (height - logo.height) // 2), logo)
    d = ImageDraw.Draw(im)
    d.text((logo.width + gap - l, (height - (b - t)) // 2 - t), text, font=font, fill=text_color)
    return im.crop(im.getbbox())


def image_svg(im, height):
    """SVG que embute o PNG `im` com altura `height` (largura proporcional)."""
    w = round(im.width * height / im.height, 2)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{w:g}" height="{height}" viewBox="0 0 {w:g} {height}">'
            f'<image width="{w:g}" height="{height}" xlink:href="data:image/png;base64,{png_b64(im)}"/></svg>\n')


def build_icons():
    fn = make_mapper([(190, 240)], min_sat=0.2, light_cap=0.45)   # pastas azuis do Adwaita -> laranja
    for sub in ("scalable", "symbolic"):
        shutil.rmtree(ICONS / sub, ignore_errors=True)
    places = ICONS / "scalable" / "places"
    places.mkdir(parents=True)
    for f in sorted((ADWAITA / "scalable" / "places").glob("*.svg")):
        text = f.read_text()
        # símbolo da pasta (último <path fill="#438de6">) em laranja bem escuro, para ter contraste
        for tag in ('<path fill="#438de6"', '<g fill="#438de6"'):
            i = text.rfind(tag)
            rest = text[i + len(tag):]
            if i != -1 and "fill=" not in rest and ("<path" not in rest or tag.startswith("<g")):
                text = text[:i] + tag.replace("#438de6", '#6b2e0b" fill-opacity="0.85') + rest
                break
        (places / f.name).write_text(recolor_text(text, fn))
    # pastas nas mimes (inode-directory) também
    mimes = ICONS / "scalable" / "mimetypes"
    mimes.mkdir(parents=True)
    src_dir = ADWAITA / "scalable" / "mimetypes" / "inode-directory.svg"
    if src_dir.exists():
        (mimes / "inode-directory.svg").write_text(recolor_text(src_dir.read_text(), fn))

    # Logo ViskooOS: botão "Mostrar aplicativos" do dock (Ubuntu Dock usa view-app-grid-ubuntu-symbolic)
    act = ICONS / "symbolic" / "actions"
    act.mkdir(parents=True)
    dock = logo_svg(ACCENT, 14 * DOCK_LOGO_SCALE)
    for name in ("view-app-grid-symbolic", "view-app-grid-ubuntu-symbolic", "view-app-grid-user-symbolic"):
        (act / f"{name}.svg").write_text(dock)
    # versões simbólicas do logo do Ubuntu
    for name in ("start-here-symbolic", "distributor-logo-symbolic", "ubuntu-logo-symbolic",
                 "ubuntu-logo-icon-symbolic", "viskooos-symbolic"):
        (act / f"{name}.svg").write_text(logo_svg(ACCENT))
    # logos coloridos: tudo que o Ubuntu chama de ubuntu-logo*/distributor-logo/start-here
    apps = ICONS / "scalable" / "apps"
    apps.mkdir(parents=True)
    square = logo_svg(ACCENT, 56, 64)
    for name in ("start-here", "distributor-logo", "ubuntu-logo", "ubuntu-logo-dark",
                 "ubuntu-logo-icon", "viskooos"):
        (apps / f"{name}.svg").write_text(square)
    # Configurações > Sobre usa LOGO=ubuntu-logo do os-release e procura primeiro "-text-dark"/"-text"
    (apps / "ubuntu-logo-text-dark.svg").write_text(image_svg(wordmark_image("#ffffff"), 72))
    (apps / "ubuntu-logo-text.svg").write_text(image_svg(wordmark_image("#1e1e1e"), 72))

    (ICONS / "index.theme").write_text("""[Icon Theme]
Name=ViskooOS
Comment=ViskooOS — ícones Adwaita com pastas laranja e cursor DMZ preto/laranja
Inherits=Adwaita,hicolor
Example=folder
Directories=scalable/places,scalable/mimetypes,scalable/apps,symbolic/actions

[scalable/places]
Context=Places
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/mimetypes]
Context=MimeTypes
Size=128
MinSize=8
MaxSize=512
Type=Scalable

[scalable/apps]
Context=Applications
Size=64
MinSize=8
MaxSize=512
Type=Scalable

[symbolic/actions]
Context=Actions
Size=16
MinSize=8
MaxSize=512
Type=Scalable
""")
    (ICONS / "cursor.theme").write_text("[Icon Theme]\nName=ViskooOS\nInherits=ViskooOS\n")


# ---------------------------------------------------------------- Branding (sistema)
def build_branding():
    """Arquivos que substituem os logos do Ubuntu fora do tema de ícones (instalados com dpkg-divert)."""
    shutil.rmtree(BRANDING, ignore_errors=True)
    pix = BRANDING / "pixmaps"
    ply = BRANDING / "plymouth-spinner"
    pix.mkdir(parents=True)
    ply.mkdir(parents=True)
    light, dark = wordmark_image("#1e1e1e"), wordmark_image("#ffffff")
    (pix / "ubuntu-logo.svg").write_text(logo_svg(ACCENT, 28, 32))
    (pix / "ubuntu-logo-text.svg").write_text(image_svg(light, 72))
    (pix / "ubuntu-logo-text-dark.svg").write_text(image_svg(dark, 72))

    def fit(im, w, h):                         # cabe em w x h, centralizado, fundo transparente
        im = im.copy(); im.thumbnail((w, h), Image.LANCZOS)
        out = Image.new("RGBA", (w, h)); out.paste(im, ((w - im.width) // 2, (h - im.height) // 2), im)
        return out
    fit(light, 187, 60).save(pix / "ubuntu-logo-text.png")
    fit(dark, 187, 60).save(pix / "ubuntu-logo-text-dark.png")
    # tema de boot reserva do Ubuntu (spinner/bgrt): marca d'água embaixo e logo de fallback
    fit(wordmark_image("#ffffff", "#ffffff"), 187, 60).save(ply / "watermark.png")
    fit(logo_image("#ffffff"), 96, 96).resize((96, 96)).save(ply / "_logo96.png")
    out = Image.new("RGBA", (128, 128)); out.paste(Image.open(ply / "_logo96.png"), (16, 16))
    out.save(ply / "bgrt-fallback.png"); (ply / "_logo96.png").unlink()


# ---------------------------------------------------------------- Cursor
def xcur_read(data):
    assert data[:4] == b"Xcur", "não é Xcursor"
    n = struct.unpack("<I", data[12:16])[0]
    imgs = []
    for i in range(n):
        typ, sub, pos = struct.unpack("<III", data[16 + 12 * i:28 + 12 * i])
        if typ != 0xFFFD0002:
            continue
        _, _, _, _, w, h, xh, yh, delay = struct.unpack("<9I", data[pos:pos + 36])
        px = list(struct.unpack("<%dI" % (w * h), data[pos + 36:pos + 36 + 4 * w * h]))
        imgs.append([sub, w, h, xh, yh, delay, px])
    return imgs


def xcur_write(imgs):
    n = len(imgs)
    head = bytearray(b"Xcur" + struct.pack("<III", 16, 0x10000, n))
    pos, body = 16 + 12 * n, bytearray()
    for sub, w, h, xh, yh, delay, px in imgs:
        head += struct.pack("<III", 0xFFFD0002, sub, pos + len(body))
        body += struct.pack("<9I", 36, 0xFFFD0002, sub, 1, w, h, xh, yh, delay)
        body += struct.pack("<%dI" % len(px), *px)
    return bytes(head + body)


def cursor_pixel(p):
    """Contorno branco do DMZ-Black vira laranja (pixels são ARGB pré-multiplicados)."""
    a = p >> 24
    if a == 0:
        return p
    r, g, b = (p >> 16) & 255, (p >> 8) & 255, p & 255
    ur, ug, ub = (min(255, c * 255 // a) for c in (r, g, b))     # desfaz pré-multiplicação
    h, l, s = colorsys.rgb_to_hls(ur / 255, ug / 255, ub / 255)
    if s > 0.15 or l < 0.55:
        return p
    t = (l - 0.55) / 0.45                                          # 0 (cinza) .. 1 (branco)
    ar, ag, ab = (int(ACCENT[i:i + 2], 16) for i in (1, 3, 5))
    nr, ng, nb = (round(c * t + v * (1 - t)) for c, v in ((ar, ur), (ag, ug), (ab, ub)))
    return (a << 24) | ((nr * a // 255) << 16) | ((ng * a // 255) << 8) | (nb * a // 255)


def build_cursors():
    dest = ICONS / "cursors"
    dest.mkdir(parents=True)
    done = {}
    for f in sorted(DMZ.iterdir()):
        real = f.resolve()
        if real.name not in done:
            imgs = xcur_read(real.read_bytes())
            for im in imgs:
                im[6] = [cursor_pixel(p) for p in im[6]]
            (dest / real.name).write_bytes(xcur_write(imgs))
            done[real.name] = True
        if f.is_symlink() and f.name != real.name:
            (dest / f.name).symlink_to(real.name)


if __name__ == "__main__":
    steps = set(sys.argv[1:]) or {"gtk", "shell", "icons", "cursor", "branding"}
    need = {"gtk": [YARU_DARK], "shell": [SHELL_BASE], "icons": [ADWAITA, FONT],
            "cursor": [DMZ], "branding": [FONT]}
    for p in [LOGO] + [p for s in steps for p in need.get(s, [])]:
        if not p.exists():
            sys.exit(f"Base não encontrada: {p}")
    THEME.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)
    if "gtk" in steps:      print("GTK...");      build_gtk()
    if "shell" in steps:    print("Shell...");    build_shell(); build_theme_index()
    if "icons" in steps:    print("Ícones...");   build_icons()
    if "cursor" in steps:
        print("Cursor...")
        shutil.rmtree(ICONS / "cursors", ignore_errors=True); build_cursors()
    if "branding" in steps: print("Branding..."); build_branding()
    print(f"Pronto:\n  {THEME}\n  {ICONS}")
