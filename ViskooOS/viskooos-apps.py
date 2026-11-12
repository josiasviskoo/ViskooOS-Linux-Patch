#!/usr/bin/env python3
"""ViskooOS Apps — interface gráfica (GTK4 + libadwaita) do install-apps.sh.

Telas:  carregando → escolha (abas Sistema / Apps, busca e filtro por categoria) → instalação → resumo.
O catálogo e a instalação ficam no install-apps.sh:
  --catalog                        lista os apps (TSV) com o status de instalado
  --worker  [--control f] ids      instala como root (via pkexec), cada app isolado
  --worker-user [--control f] ids  extensões GNOME (como o usuário)
  --post-user ids                  ajustes de design como o usuário (ex.: tema do Zen)
Marcadores lidos da saída:  @@PHASE @@STEP @@PROG @@VIA @@ASK @@NOTE @@OK @@FAIL @@SKIP @@BUSY @@DONE
O arquivo de controle (linhas "skip <id>" / "cancel") permite pular um app ou cancelar o resto.
"""
import os
import queue
import re
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, GObject, Gtk, Pango  # noqa: E402

APP_ID = "com.viskooos.Apps"
TITLE = "ViskooOS Apps"
SYSTEM_CAT = "Sistema"
HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, "ViskooOS", "plymouth", "logo.png")
LOG = os.path.expanduser("~/.local/share/viskooos/install-apps.log")
# depois do DesViskar-OS.sh: sem o nome e o logo ViskooOS
if os.path.exists(os.path.expanduser("~/.local/share/viskooos/sem-marca")):
    TITLE = "Instalar Apps"
    LOGO = ""

CAT_ICONS = {
    "Sistema": "emblem-system-symbolic",
    "Efeitos": "applications-science-symbolic",
    "Multimídia": "applications-multimedia-symbolic",
    "Design": "applications-graphics-symbolic",
    "ArtCraft": "applications-graphics-symbolic",
    "Escritório": "x-office-document-symbolic",
    "Comunicação": "chat-symbolic",
    "Internet": "web-browser-symbolic",
    "Desenvolvimento": "utilities-terminal-symbolic",
    "Acesso remoto": "network-workgroup-symbolic",
    "Utilitários": "applications-utilities-symbolic",
}
# nomes de ícone conhecidos (o resto vem do id Flatpak / pacote)
ICON_HINTS = {
    "update": ["system-software-update"], "flatpak": ["flatpak-discover", "system-software-install"],
    "repair": ["applications-system", "preferences-system"], "snap-store": ["snap-store", "org.gnome.Software"],
    "ext-manager": ["com.mattjakeman.ExtensionManager", "org.gnome.Extensions"],
    "tweaks": ["org.gnome.tweaks", "gnome-tweaks"], "compiz-liquid": ["org.gnome.Extensions"],
    "compiz-lamp": ["org.gnome.Extensions"], "vscode": ["vscode", "code", "com.visualstudio.code"],
    "chrome": ["google-chrome", "com.google.Chrome"], "libreoffice": ["libreoffice-startcenter", "libreoffice-main"],
    "telegram": ["org.telegram.desktop", "telegram"], "anydesk": ["anydesk", "com.anydesk.Anydesk"],
    "teamviewer": ["TeamViewer", "teamviewer"], "virtualbox": ["virtualbox", "VBox"],
}
METHOD_LABEL = {
    "snap": "Snap", "flatpak": "Flatpak", "acflat": "Flatpak · ArtCraft", "acapt": "APT · ArtCraft",
    "apt": "APT", "deb": ".deb oficial", "ext": "Extensão GNOME", "fn": "Sistema",
}
CAT_NOTES = {
    "ArtCraft": "Apps de código aberto da ArtCraft (getartcraft.com/apps), via repositório APT oficial "
                "(Flatpak como reserva). Vários ainda estão em alfa.",
    "Efeitos": "Os efeitos Compiz ativam na hora: o GNOME pede uma confirmação. "
               "Use o Gerenciador de Extensões para ajustá-los.",
}
ERR_RE = re.compile(r"^(E:|✘|⚠|error|erro|fatal|falha|failed)", re.I)
BAR_JUNK = re.compile(r"[█▏▎▍▌▋▊▉░▒▓#=\-\[\]|]+")

CSS = """
@define-color accent_bg_color #ea7320;
@define-color accent_color #ff9a4d;
@define-color accent_fg_color #ffffff;
@define-color window_bg_color #141414;
@define-color view_bg_color #141414;
@define-color headerbar_bg_color #1a1a1a;
@define-color card_bg_color #1f1f1f;
:root { --accent-bg-color: #ea7320; --accent-color: #ff9a4d; --accent-fg-color: #ffffff;
        --window-bg-color: #141414; --view-bg-color: #141414; --headerbar-bg-color: #1a1a1a;
        --card-bg-color: #1f1f1f; }
window, .background { background-color: #141414; }
headerbar { box-shadow: none; border-bottom: 1px solid #242424; }

.viskoo-hero { padding: 26px 28px; border-radius: 22px; margin: 6px 0 4px 0;
  background-image: linear-gradient(120deg, #2a1a0e 0%, #1f1f1f 55%, #1a1a1a 100%);
  border: 1px solid alpha(#ea7320, 0.22); }
.viskoo-hero .title-1 { font-weight: 800; }
.viskoo-sub { color: alpha(#ffffff, 0.62); }
.viskoo-stat { font-size: 0.85em; font-weight: 700; padding: 3px 12px; border-radius: 999px;
  background-color: alpha(#ffffff, 0.07); color: alpha(#ffffff, 0.75); }

.viskoo-chips button { border-radius: 999px; padding: 4px 14px; min-height: 0;
  background-color: alpha(#ffffff, 0.06); font-weight: 600; }
.viskoo-chips button:checked { background-color: #ea7320; color: #ffffff; }

list.boxed-list, .boxed-list { background-color: #1e1e1e; border-radius: 16px; }
.viskoo-tile { border-radius: 12px; background-color: alpha(#ea7320, 0.16); color: #ff9a4d; padding: 7px; }
.viskoo-badge { font-size: 0.78em; font-weight: 700; padding: 2px 10px; border-radius: 999px;
  background-color: alpha(#3fbf6a, 0.16); color: #74d993; }
.viskoo-method { font-size: 0.76em; padding: 2px 9px; border-radius: 999px;
  background-color: alpha(#ffffff, 0.07); color: alpha(#ffffff, 0.6); }

.viskoo-bar { background-color: #1a1a1a; border-top: 1px solid #242424; padding: 12px 18px; }
.viskoo-bar .title { font-weight: 700; }
button.viskoo-go { border-radius: 999px; padding: 9px 30px; font-weight: 800; }

.viskoo-card { border-radius: 22px; padding: 24px; background-color: #1d1d1d; border: 1px solid #272727; }
.viskoo-card.done-ok { border-color: alpha(#3fbf6a, 0.45);
  background-image: linear-gradient(120deg, alpha(#3fbf6a, 0.10), #1d1d1d 60%); }
.viskoo-card.done-fail { border-color: alpha(#ff6b5b, 0.45);
  background-image: linear-gradient(120deg, alpha(#ff6b5b, 0.10), #1d1d1d 60%); }
.viskoo-pct { font-size: 2.1em; font-weight: 800; color: #ff9a4d; font-feature-settings: "tnum"; }
.viskoo-cap { font-size: 0.82em; font-weight: 700; color: alpha(#ffffff, 0.5); letter-spacing: 1px; }

progressbar trough { min-height: 8px; border-radius: 999px; background-color: #2a2a2a; }
progressbar progress { min-height: 8px; border-radius: 999px;
  background-image: linear-gradient(90deg, #ea7320, #ffa55c); background-color: #ea7320; border: none; }
progressbar.viskoo-big trough, progressbar.viskoo-big progress { min-height: 12px; }
progressbar.viskoo-thin trough, progressbar.viskoo-thin progress { min-height: 4px; }

.viskoo-log { font-family: monospace; font-size: 0.85em; background-color: #0d0d0d; color: #d0d0d0;
  border-radius: 14px; padding: 12px; }
.viskoo-log text { background-color: #0d0d0d; }
.viskoo-ok { color: #6fd38a; }
.viskoo-fail { color: #ff6b5b; }
.viskoo-skip { color: alpha(#ffffff, 0.45); }
row.viskoo-running { background-color: alpha(#ea7320, 0.08); }
"""


def clean_text(s):
    s = BAR_JUNK.sub(" ", s)
    s = re.sub(r"\s{2,}", " ", s).strip(" .…")
    return s[:90]


class Item:
    def __init__(self, row):
        (self.id, d, self.cat, self.name, self.desc, self.meth, inst, srcs) = row
        self.default = d == "1"
        self.installed = inst == "1"
        self.srcs = srcs.split()
        self.check = self.row = None
        self.reset()

    def reset(self):
        self.state = "queue"     # queue | run | ok | fail | skip
        self.pct = 0
        self.via = ""
        self.reason = ""
        self.lines = []

    def icon_candidates(self):
        names = list(ICON_HINTS.get(self.id, []))
        for s in self.srcs:
            m, _, t = s.partition(":")
            if m in ("flatpak", "acflat"):
                names.append(t)
            elif m in ("apt", "acapt"):
                names.append(t.split(",")[0])
            elif m == "snap":
                names.append(t)
            elif m == "deb":
                names.append(t.split("=")[0])
        names.append(self.id)
        return names


def app_icon(it, size):
    """Ícone real do app, se o tema tiver; senão um 'tile' com o ícone da categoria."""
    theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default())
    for n in it.icon_candidates():
        if n and theme.has_icon(n):
            return Gtk.Image(icon_name=n, pixel_size=size)
    img = Gtk.Image(icon_name=CAT_ICONS.get(it.cat, "application-x-executable-symbolic"),
                    pixel_size=max(size - 16, 16), css_classes=["viskoo-tile"])
    return img


def spinner():
    if hasattr(Adw, "Spinner"):
        s = Adw.Spinner()
    else:
        s = Gtk.Spinner(spinning=True)
    s.set_size_request(20, 20)
    return s


class Win(Adw.ApplicationWindow):
    def __init__(self, app, backend, dry):
        super().__init__(application=app, title=TITLE)
        self.backend, self.dry = backend, dry
        self.items, self.groups = [], []
        self.running = False
        self.cat_filter = None
        self.set_default_size(1040, 800)
        self.connect("close-request", self.on_close_request)

        self.toast = Adw.ToastOverlay()
        self.pages = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE, transition_duration=220)
        self.toast.set_child(self.pages)
        self.set_content(self.toast)

        load = Adw.StatusPage(title="Verificando o que já está instalado…",
                              description="Isso leva só alguns segundos.")
        sp = Adw.Spinner() if hasattr(Adw, "Spinner") else Gtk.Spinner(spinning=True)
        sp.set_size_request(48, 48)
        load.set_child(sp)
        self.pages.add_named(self.wrap(load), "load")
        threading.Thread(target=self.load_catalog, daemon=True).start()

    @staticmethod
    def wrap(child, header=None):
        tv = Adw.ToolbarView()
        tv.add_top_bar(header or Adw.HeaderBar())
        tv.set_content(child)
        return tv

    # ───────────────────────────── catálogo ─────────────────────────────
    def load_catalog(self):
        try:
            out = subprocess.run(["bash", self.backend, "--catalog"], capture_output=True,
                                 text=True, timeout=180).stdout
            rows = [ln.split("\t") for ln in out.splitlines() if ln.count("\t") == 7]
            if not rows:
                raise RuntimeError("o install-apps.sh não devolveu nenhum app")
            GLib.idle_add(self.build_main, [Item(r) for r in rows])
        except Exception as e:  # noqa: BLE001
            GLib.idle_add(self.fatal, str(e))

    def fatal(self, msg):
        sp = Adw.StatusPage(icon_name="dialog-error-symbolic", title="Não foi possível ler o catálogo",
                            description=GLib.markup_escape_text(msg))
        self.pages.add_named(self.wrap(sp), "err")
        self.pages.set_visible_child_name("err")

    def build_main(self, items):
        self.items = items
        self.byid = {i.id: i for i in items}
        stack = Adw.ViewStack()
        self.stack = stack
        sys_items = [i for i in items if i.cat == SYSTEM_CAT]
        app_items = [i for i in items if i.cat != SYSTEM_CAT]
        for it in sys_items:
            it.initial = it.default and (not it.installed or it.meth == "fn")
        for it in app_items:
            it.initial = False

        self.p_sys = stack.add_titled_with_icon(self.build_tab(sys_items, True), "sistema",
                                                "Sistema", "emblem-system-symbolic")
        self.p_apps = stack.add_titled_with_icon(self.build_tab(app_items, False), "apps",
                                                 "Apps", "view-app-grid-symbolic")

        header = Adw.HeaderBar()
        header.set_title_widget(Adw.ViewSwitcher(stack=stack, policy=Adw.ViewSwitcherPolicy.WIDE))
        self.search_btn = Gtk.ToggleButton(icon_name="system-search-symbolic", tooltip_text="Buscar (Ctrl+F)")
        header.pack_start(self.search_btn)
        menu = Gio.Menu()
        menu.append("Abrir log", "win.log")
        menu.append("Desmarcar todos os apps", "win.clear")
        header.pack_end(Gtk.MenuButton(icon_name="open-menu-symbolic", menu_model=menu))
        for name, cb in (("log", lambda *_: self.open_log()),
                         ("clear", lambda *_: [i.check.set_active(False) for i in app_items])):
            a = Gio.SimpleAction.new(name, None)
            a.connect("activate", cb)
            self.add_action(a)

        self.search = Gtk.SearchEntry(placeholder_text="Buscar aplicativo…", hexpand=True)
        self.search.connect("search-changed", lambda *_: self.apply_filter())
        sbar = Gtk.SearchBar(child=Adw.Clamp(maximum_size=640, child=self.search))
        sbar.connect_entry(self.search)
        sbar.set_key_capture_widget(self)
        self.search_btn.bind_property("active", sbar, "search-mode-enabled", GObject.BindingFlags.BIDIRECTIONAL)
        sbar.connect("notify::search-mode-enabled",
                     lambda b, _p: b.get_search_mode() and stack.set_visible_child_name("apps"))

        bar = Gtk.Box(spacing=14, css_classes=["viskoo-bar"])
        txt = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True, valign=Gtk.Align.CENTER)
        self.count = Gtk.Label(xalign=0, css_classes=["title"])
        self.count_sub = Gtk.Label(xalign=0, css_classes=["viskoo-sub", "caption"],
                                   ellipsize=Pango.EllipsizeMode.END)
        txt.append(self.count)
        txt.append(self.count_sub)
        bar.append(txt)
        if self.dry:
            bar.append(Gtk.Label(label="modo simulação", css_classes=["viskoo-method"], valign=Gtk.Align.CENTER))
        self.install_btn = Gtk.Button(label="Instalar", css_classes=["suggested-action", "viskoo-go"],
                                      valign=Gtk.Align.CENTER)
        self.install_btn.connect("clicked", lambda *_: self.start_install(self.selected()))
        bar.append(self.install_btn)

        tv = Adw.ToolbarView(top_bar_style=Adw.ToolbarStyle.FLAT)
        tv.add_top_bar(header)
        tv.add_top_bar(sbar)
        tv.set_content(stack)
        tv.add_bottom_bar(bar)
        self.pages.add_named(tv, "main")
        self.pages.set_visible_child_name("main")
        stack.set_visible_child_name("apps")
        self.update_count()

    def build_tab(self, items, system):
        page = Adw.PreferencesPage()
        g = Adw.PreferencesGroup()
        hero = Gtk.Box(spacing=20, css_classes=["viskoo-hero"])
        if os.path.exists(LOGO):
            pic = Gtk.Picture.new_for_filename(LOGO)
            pic.set_size_request(64, 64)
            pic.set_can_shrink(True)
            pic.set_content_fit(Gtk.ContentFit.CONTAIN)
            hero.append(pic)
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, hexpand=True, valign=Gtk.Align.CENTER)
        col.append(Gtk.Label(label="Sistema" if system else "Aplicativos", xalign=0, css_classes=["title-1"]))
        col.append(Gtk.Label(
            label=("Manutenção que roda antes dos apps. As recomendadas já vêm marcadas."
                   if system else "Escolha o que quiser. Cada app instala separado: se um falhar, os outros continuam."),
            xalign=0, wrap=True, css_classes=["viskoo-sub"]))
        stats = Gtk.Box(spacing=8, margin_top=4)
        n_inst = sum(1 for i in items if i.installed and i.meth != "fn")
        stats.append(Gtk.Label(label=f"{len(items)} disponíveis", css_classes=["viskoo-stat"]))
        if n_inst:
            stats.append(Gtk.Label(label=f"{n_inst} já instalados", css_classes=["viskoo-stat"]))
        col.append(stats)
        hero.append(col)
        g.add(hero)
        page.add(g)

        cats = []
        for it in items:
            if it.cat not in cats:
                cats.append(it.cat)

        if not system:   # filtro por categoria
            if hasattr(Adw, "WrapBox"):
                chips = Adw.WrapBox(child_spacing=6, line_spacing=6, css_classes=["viskoo-chips"], margin_top=6)
            else:
                chips = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, css_classes=["viskoo-chips"],
                                    row_spacing=6, column_spacing=6, max_children_per_line=20, margin_top=6)
            first = None
            for c in [None] + cats:
                b = Gtk.ToggleButton(label=c or "Todos", active=c is None)
                if first is None:
                    first = b
                else:
                    b.set_group(first)
                b.connect("toggled", self.on_chip, c)
                chips.append(b)
            cg = Adw.PreferencesGroup()
            cg.add(chips)
            page.add(cg)

        for cat in cats:
            members = [i for i in items if i.cat == cat]
            grp = Adw.PreferencesGroup(title="Manutenção" if system else cat,
                                       description=CAT_NOTES.get(cat, ""))
            if not system and len(members) > 2:
                b = Gtk.Button(label="Marcar todos", css_classes=["flat", "pill"], valign=Gtk.Align.CENTER)
                b.connect("clicked", self.toggle_group, members)
                grp.set_header_suffix(b)
            for it in members:
                grp.add(self.build_row(it))
            page.add(grp)
            self.groups.append((grp, members, cat))
        return page

    def build_row(self, it):
        row = Adw.ActionRow(title=GLib.markup_escape_text(it.name), subtitle=GLib.markup_escape_text(it.desc),
                            subtitle_lines=2)
        chk = Gtk.CheckButton(active=it.initial, valign=Gtk.Align.CENTER, css_classes=["selection-mode"])
        chk.connect("toggled", lambda *_: self.update_count())
        row.add_prefix(chk)
        ic = app_icon(it, 40)
        ic.set_valign(Gtk.Align.CENTER)
        row.add_prefix(ic)
        row.set_activatable_widget(chk)
        if it.installed and it.meth != "fn":
            row.add_suffix(Gtk.Label(label="Instalado", valign=Gtk.Align.CENTER, css_classes=["viskoo-badge"]))
        row.add_suffix(Gtk.Label(label=METHOD_LABEL.get(it.meth, it.meth), valign=Gtk.Align.CENTER,
                                 css_classes=["viskoo-method"]))
        it.check, it.row = chk, row
        return row

    def toggle_group(self, _b, members):
        target = not all(m.check.get_active() for m in members)
        for m in members:
            m.check.set_active(target)

    def on_chip(self, btn, cat):
        if btn.get_active():
            self.cat_filter = cat
            self.apply_filter()

    def apply_filter(self):
        q = self.search.get_text().strip().lower() if hasattr(self, "search") else ""
        for grp, members, cat in self.groups:
            if cat == SYSTEM_CAT:
                continue
            vis = 0
            for m in members:
                ok = (self.cat_filter in (None, cat)) and (
                    not q or q in m.name.lower() or q in m.desc.lower() or q in m.cat.lower())
                m.row.set_visible(ok)
                vis += ok
            grp.set_visible(vis > 0)

    def selected(self):
        return [i for i in self.items if i.check and i.check.get_active()]

    def update_count(self):
        sel = self.selected()
        apps = [i for i in sel if i.cat != SYSTEM_CAT]
        n_sys = len(sel) - len(apps)
        if not sel:
            self.count.set_label("Nada selecionado")
            self.count_sub.set_label("Marque os apps que deseja instalar")
        else:
            self.count.set_label(f"{len(apps)} app(s) · {n_sys} tarefa(s) do sistema")
            self.count_sub.set_label(", ".join(i.name for i in sel))
        self.install_btn.set_sensitive(bool(sel))
        self.install_btn.set_label(f"Instalar ({len(sel)})" if sel else "Instalar")
        self.p_apps.set_badge_number(len(apps))
        self.p_sys.set_badge_number(n_sys)
        for grp, members, _c in self.groups:
            b = grp.get_header_suffix()
            if isinstance(b, Gtk.Button):
                b.set_label("Desmarcar todos" if all(m.check.get_active() for m in members) else "Marcar todos")

    # ───────────────────────────── instalação ─────────────────────────────
    def start_install(self, sel):
        if not sel:
            return
        for i in sel:
            i.reset()
        self.queue = sel
        self.root_ids = [i.id for i in sel if i.meth != "ext"]
        self.user_ids = [i.id for i in sel if i.meth == "ext"]
        self.current = None
        self.auth_failed = self.busy = self.need_relog = self.cancelled = False
        self.got_root_output = False
        run_dir = GLib.get_user_runtime_dir() or GLib.get_tmp_dir()
        self.control = os.path.join(run_dir, f"viskooos-apps-{os.getpid()}.ctl")
        open(self.control, "w").close()
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        self.logf = open(LOG, "a", buffering=1)
        self.logf.write(f"\n===== {GLib.DateTime.new_now_local().format('%F %T')}  {TITLE}  "
                        f"{' '.join(self.root_ids + self.user_ids)}\n")
        self.lines = queue.Queue()
        self.build_progress()
        self.running = True
        self.pulse_id = GLib.timeout_add(110, self.pulse)
        self.drain_id = GLib.timeout_add(60, self.drain)
        threading.Thread(target=self.worker, daemon=True).start()

    def build_progress(self):
        if self.pages.get_child_by_name("progress"):
            self.pages.remove(self.pages.get_child_by_name("progress"))
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18, margin_top=22, margin_bottom=22,
                      margin_start=22, margin_end=22)

        # cartão principal
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14, css_classes=["viskoo-card"])
        self.card = card
        top = Gtk.Box(spacing=18)
        self.cur_icon_slot = Adw.Bin(valign=Gtk.Align.CENTER)
        self.cur_icon_slot.set_child(Gtk.Image(icon_name="system-software-install-symbolic", pixel_size=40,
                                               css_classes=["viskoo-tile"]))
        top.append(self.cur_icon_slot)
        col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, hexpand=True, valign=Gtk.Align.CENTER)
        self.p_title = Gtk.Label(label="Preparando…", xalign=0, css_classes=["title-2"],
                                 ellipsize=Pango.EllipsizeMode.END)
        self.p_sub = Gtk.Label(label="Digite sua senha na janela do sistema, se pedir.", xalign=0,
                               css_classes=["viskoo-sub"], ellipsize=Pango.EllipsizeMode.END)
        col.append(self.p_title)
        col.append(self.p_sub)
        top.append(col)
        self.p_pct = Gtk.Label(label="", css_classes=["viskoo-pct"], valign=Gtk.Align.CENTER)
        top.append(self.p_pct)
        card.append(top)

        self.cur_bar = Gtk.ProgressBar(css_classes=["viskoo-thin"])
        card.append(self.cur_bar)

        orow = Gtk.Box(spacing=10, margin_top=6)
        self.o_cap = Gtk.Label(label="PROGRESSO GERAL", xalign=0, css_classes=["viskoo-cap"], hexpand=True)
        self.o_count = Gtk.Label(label=f"0 de {len(self.queue)}", css_classes=["viskoo-cap"])
        orow.append(self.o_cap)
        orow.append(self.o_count)
        card.append(orow)
        self.pbar = Gtk.ProgressBar(css_classes=["viskoo-big"])
        card.append(self.pbar)

        self.actions = Gtk.Box(spacing=8, halign=Gtk.Align.END, margin_top=4)
        self.skip_btn = Gtk.Button(label="Pular este app", css_classes=["flat", "pill"], sensitive=False,
                                   tooltip_text="Interrompe só o app atual; os outros continuam")
        self.skip_btn.connect("clicked", self.on_skip)
        self.cancel_btn = Gtk.Button(label="Cancelar o restante", css_classes=["flat", "pill", "destructive-action"])
        self.cancel_btn.connect("clicked", lambda *_: self.ask_cancel())
        self.actions.append(self.skip_btn)
        self.actions.append(self.cancel_btn)
        card.append(self.actions)

        self.done_actions = Gtk.Box(spacing=8, halign=Gtk.Align.END, margin_top=4, visible=False)
        self.retry_btn = Gtk.Button(label="Tentar de novo as que falharam", css_classes=["pill"])
        self.retry_btn.connect("clicked", self.on_retry)
        logb = Gtk.Button(label="Abrir log", css_classes=["flat", "pill"])
        logb.connect("clicked", lambda *_: self.open_log())
        back = Gtk.Button(label="Instalar mais apps", css_classes=["flat", "pill"])
        back.connect("clicked", lambda *_: self.back_to_main())
        self.finish_btn = Gtk.Button(label="Concluir", css_classes=["suggested-action", "viskoo-go"])
        self.finish_btn.connect("clicked", lambda *_: self.close())
        for w in (logb, back, self.retry_btn, self.finish_btn):
            self.done_actions.append(w)
        card.append(self.done_actions)
        box.append(card)

        self.banner = Adw.Banner(title="", revealed=False)
        box.append(self.banner)

        # fila
        self.steps = Gtk.ListBox(css_classes=["boxed-list"], selection_mode=Gtk.SelectionMode.NONE)
        for it in self.queue:
            r = Adw.ActionRow(title=GLib.markup_escape_text(it.name), subtitle="Na fila")
            ic = app_icon(it, 32)
            ic.set_valign(Gtk.Align.CENTER)
            r.add_prefix(ic)
            slot = Gtk.Box(spacing=8, valign=Gtk.Align.CENTER)
            slot.append(Gtk.Image(icon_name="content-loading-symbolic", css_classes=["viskoo-skip"]))
            r.add_suffix(slot)
            it.prow, it.pslot = r, slot
            self.steps.append(r)
        box.append(self.steps)

        # terminal
        self.logbuf = Gtk.TextBuffer()
        self.logview = Gtk.TextView(buffer=self.logbuf, editable=False, monospace=True, cursor_visible=False,
                                    wrap_mode=Gtk.WrapMode.WORD_CHAR, css_classes=["viskoo-log"])
        self.logscroll = Gtk.ScrolledWindow(min_content_height=240, child=self.logview)
        box.append(Gtk.Expander(label="Mostrar a saída do terminal", child=self.logscroll))

        scroller = Gtk.ScrolledWindow(vexpand=True, child=Adw.Clamp(maximum_size=820, child=box))
        hb = Adw.HeaderBar()
        self.p_wtitle = Adw.WindowTitle(title=TITLE, subtitle="Instalando" + (" (simulação)" if self.dry else ""))
        hb.set_title_widget(self.p_wtitle)
        self.pages.add_named(self.wrap(scroller, hb), "progress")
        self.pages.set_visible_child_name("progress")

    def set_slot(self, it, *widgets):
        child = it.pslot.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            it.pslot.remove(child)
            child = nxt
        for w in widgets:
            it.pslot.append(w)

    # ── processos ──
    def stream(self, cmd):
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                 bufsize=1, errors="replace", stdin=subprocess.DEVNULL)
        except OSError as e:
            self.lines.put(f"✘ não consegui iniciar {cmd[0]}: {e}")
            return 127
        for line in p.stdout:
            self.lines.put(line.rstrip("\n"))
        return p.wait()

    def worker(self):
        ctl = ["--control", self.control]
        dry = ["--dry-run"] if self.dry else []
        if self.root_ids:
            if self.dry:
                cmd = ["bash", self.backend, "--worker", "--dry-run", *ctl, *self.root_ids]
            else:
                cmd = ["pkexec", "bash", self.backend, "--worker", *ctl, *self.root_ids]
            rc = self.stream(cmd)
            if rc in (126, 127) and not self.dry:
                self.lines.put("@@AUTHFAIL")
        if self.user_ids:
            self.stream(["bash", self.backend, "--worker-user", *dry, *ctl, *self.user_ids])
        if self.root_ids:
            self.stream(["bash", self.backend, "--post-user", *dry, *self.root_ids])
        self.lines.put("@@FINISH")

    def drain(self):
        n = 0
        try:
            while n < 400:
                self.on_line(self.lines.get_nowait())
                n += 1
        except queue.Empty:
            pass
        return self.running or not self.lines.empty()

    def on_line(self, line):
        if not line.startswith("@@"):
            self.log(line)
            if self.current:
                self.current.lines.append(line)
            return
        tag, _, rest = line.partition(" ")
        if tag == "@@FINISH":
            self.finish()
        elif tag == "@@PHASE":
            self.got_root_output = True
            self.p_title.set_label(rest)
            self.p_sub.set_label("Pausando atualizações automáticas e conferindo o APT")
        elif tag == "@@STEP":
            self.got_root_output = True
            self.start_item(self.byid.get(rest))
        elif tag == "@@PROG":
            iid, _, r = rest.partition(" ")
            pct_s, _, msg = r.partition("\t")
            try:
                pct = int(pct_s)
            except ValueError:
                return
            self.on_progress(iid, pct, clean_text(msg))
        elif tag == "@@VIA":
            iid, _, via = rest.partition(" ")
            if iid in self.byid:
                self.byid[iid].via = via
        elif tag == "@@ASK":
            _iid, _, msg = rest.partition(" ")
            self.banner.set_title(msg or "Confirme na janela do GNOME")
            self.banner.set_revealed(True)
        elif tag == "@@NOTE":
            if rest.strip() == "relog":
                self.need_relog = True
        elif tag in ("@@OK", "@@FAIL", "@@SKIP"):
            iid, _, why = rest.partition(" ")
            self.end_item(self.byid.get(iid), {"@@OK": "ok", "@@FAIL": "fail", "@@SKIP": "skip"}[tag], why)
        elif tag == "@@AUTHFAIL":
            self.auth_failed = True
        elif tag == "@@BUSY":
            self.busy = True
        # @@DONE e desconhecidos: ignorados

    def start_item(self, it):
        if not it:
            return
        it.state, it.pct = "run", -1
        self.current = it
        self.banner.set_revealed(False)
        idx = self.queue.index(it) + 1 if it in self.queue else 0
        self.p_title.set_label(it.name if it.cat == SYSTEM_CAT else f"Instalando {it.name}")
        self.p_sub.set_label("Começando…")
        self.p_pct.set_label("")
        self.cur_icon_slot.set_child(app_icon(it, 48))
        self.o_count.set_label(f"{idx} de {len(self.queue)}")
        self.skip_btn.set_sensitive(True)
        self.log(f"\n==> {it.name}", bold=True)
        it.prow.add_css_class("viskoo-running")
        it.prow.set_subtitle("Instalando…")
        bar = Gtk.ProgressBar(css_classes=["viskoo-thin"], valign=Gtk.Align.CENTER)
        bar.set_size_request(110, -1)
        it.pbar_small = bar
        self.set_slot(it, bar, spinner())
        self.update_overall()

    def on_progress(self, iid, pct, msg):
        if iid == "prep":
            self.cur_bar.set_fraction(max(pct, 0) / 100)
            self.p_pct.set_label(f"{pct}%" if pct >= 0 else "")
            if msg:
                self.p_sub.set_label(msg)
            return
        it = self.byid.get(iid)
        if not it or it is not self.current:
            return
        it.pct = pct
        if pct >= 0:
            self.cur_bar.set_fraction(pct / 100)
            self.p_pct.set_label(f"{pct}%")
            it.pbar_small.set_fraction(pct / 100)
        else:
            self.p_pct.set_label("")
        if msg:
            self.p_sub.set_label(msg)
            it.prow.set_subtitle(GLib.markup_escape_text(msg))
        self.update_overall()

    def end_item(self, it, state, why):
        if not it:
            return
        it.state = state
        it.pct = 100
        it.prow.remove_css_class("viskoo-running")
        if state == "ok":
            it.prow.set_subtitle("Instalado" + (f" via {METHOD_LABEL.get(it.via, it.via)}" if it.via else ""))
            self.set_slot(it, Gtk.Image(icon_name="object-select-symbolic", css_classes=["viskoo-ok"]))
            self.log("✔ " + it.name)
        else:
            if state == "skip":
                it.reason = "pulado" if not self.cancelled else "cancelado"
                it.prow.set_subtitle(it.reason.capitalize())
                ic = Gtk.Image(icon_name="media-skip-forward-symbolic", css_classes=["viskoo-skip"])
            else:
                errs = [ln for ln in it.lines if ERR_RE.search(ln.strip())]
                it.reason = clean_text((errs[-1] if errs else why) or "falhou") or "falhou"
                it.prow.set_subtitle(GLib.markup_escape_text("Falhou: " + it.reason))
                ic = Gtk.Image(icon_name="dialog-error-symbolic", css_classes=["viskoo-fail"])
            btn = Gtk.Button(icon_name="document-open-recent-symbolic", tooltip_text="Ver o que aconteceu",
                             css_classes=["flat", "circular"])
            btn.connect("clicked", lambda *_: self.show_item_log(it))
            self.set_slot(it, btn, ic)
        if it is self.current:
            self.current = None
            self.skip_btn.set_sensitive(False)
            self.cur_bar.set_fraction(0)
            self.p_pct.set_label("")
        self.update_overall()

    def update_overall(self):
        total = max(len(self.queue), 1)
        done = sum(1 for i in self.queue if i.state in ("ok", "fail", "skip"))
        cur = self.current.pct / 100 if self.current and self.current.pct > 0 else 0
        self.pbar.set_fraction(min((done + cur) / total, 1))
        self.p_wtitle.set_subtitle(f"{int(min((done + cur) / total, 1) * 100)}% · {done} de {total}"
                                   + (" (simulação)" if self.dry else ""))

    def pulse(self):
        if not self.running:
            return False
        if self.current and self.current.pct < 0:
            self.cur_bar.pulse()
            self.current.pbar_small.pulse()
        elif self.current is None and not self.got_root_output:
            self.cur_bar.pulse()
        return True

    def write_ctl(self, line):
        try:
            with open(self.control, "a") as f:
                f.write(line + "\n")
        except OSError:
            pass

    def on_skip(self, _b):
        if self.current:
            self.write_ctl(f"skip {self.current.id}")
            self.p_sub.set_label("Interrompendo este app…")
            self.skip_btn.set_sensitive(False)

    def ask_cancel(self, then_close=False):
        d = Adw.AlertDialog(heading="Parar a instalação?",
                            body="O app que está instalando agora é interrompido com segurança e os "
                                 "próximos da fila não serão instalados.")
        d.add_response("keep", "Continuar instalando")
        d.add_response("stop", "Parar")
        d.set_response_appearance("stop", Adw.ResponseAppearance.DESTRUCTIVE)
        d.set_default_response("keep")

        def resp(_d, r):
            if r == "stop":
                self.cancelled = True
                self.write_ctl("cancel")
                self.p_sub.set_label("Parando com segurança…")
                self.cancel_btn.set_sensitive(False)
                self.skip_btn.set_sensitive(False)
                self.close_after = then_close
        d.connect("response", resp)
        d.present(self)

    def on_close_request(self, _w):
        if self.running:
            self.ask_cancel(then_close=True)
            return True
        return False

    def log(self, text, bold=False):
        self.logbuf.insert(self.logbuf.get_end_iter(), text + "\n")
        if self.logbuf.get_line_count() > 6000:
            s = self.logbuf.get_start_iter()
            self.logbuf.delete(s, self.logbuf.get_iter_at_line(1000)[1])
        adj = self.logscroll.get_vadjustment()
        GLib.idle_add(lambda: adj.set_value(adj.get_upper()) or False)
        try:
            self.logf.write(text + "\n")
        except (OSError, ValueError):
            pass

    def show_item_log(self, it):
        tv = Gtk.TextView(editable=False, monospace=True, wrap_mode=Gtk.WrapMode.WORD_CHAR,
                          css_classes=["viskoo-log"])
        tv.get_buffer().set_text("\n".join(it.lines[-400:]) or "(sem saída)")
        sc = Gtk.ScrolledWindow(child=tv, min_content_height=380, min_content_width=640)
        d = Adw.AlertDialog(heading=it.name, body=it.reason.capitalize() if it.reason else "")
        d.set_extra_child(sc)
        d.add_response("close", "Fechar")
        d.present(self)

    def finish(self):
        self.running = False
        try:
            os.unlink(self.control)
        except OSError:
            pass
        for it in self.queue:
            if it.state in ("queue", "run"):
                it.state = "skip" if self.cancelled else "fail"
                it.reason = "cancelado" if self.cancelled else "não executado"
                it.prow.remove_css_class("viskoo-running")
                it.prow.set_subtitle(it.reason.capitalize())
                self.set_slot(it, Gtk.Image(icon_name="media-skip-forward-symbolic", css_classes=["viskoo-skip"]))
        ok = [i for i in self.queue if i.state == "ok"]
        bad = [i for i in self.queue if i.state != "ok"]
        self.current = None
        self.banner.set_revealed(False)
        self.pbar.set_fraction(1)
        self.cur_bar.set_visible(False)
        self.p_pct.set_label("")
        self.actions.set_visible(False)
        self.done_actions.set_visible(True)
        self.retry_btn.set_visible(bool(bad) and not self.auth_failed)
        self.o_count.set_label(f"{len(ok)} de {len(self.queue)}")
        self.p_wtitle.set_subtitle("Concluído" + (" (simulação)" if self.dry else ""))

        if self.busy:
            title, sub, good = "Outra instalação já está rodando", "Espere ela terminar e tente de novo.", False
        elif self.auth_failed and not self.got_root_output:
            title, sub, good = "Senha cancelada ou recusada", "Os apps do sistema não foram instalados.", False
            self.retry_btn.set_visible(True)
        elif bad:
            title = f"Concluído: {len(ok)} instalado(s), {len(bad)} com problema"
            sub, good = "Toque no ícone ao lado de cada item para ver o que aconteceu.", False
        else:
            title = "Tudo pronto!"
            sub = f"{len(ok)} item(ns) instalado(s) e conferido(s)" + (" (simulação)" if self.dry else "") + "."
            good = True
        self.p_title.set_label(title)
        self.p_sub.set_label(sub)
        self.card.add_css_class("done-ok" if good else "done-fail")
        self.cur_icon_slot.set_child(Gtk.Image(
            icon_name="object-select-symbolic" if good else "dialog-warning-symbolic", pixel_size=40,
            css_classes=["viskoo-tile", "viskoo-ok" if good else "viskoo-fail"]))
        if self.need_relog:
            self.toast.add_toast(Adw.Toast(title="Alguns efeitos Compiz ativam depois de sair e entrar na sessão.",
                                           timeout=0))
        try:
            self.logf.close()
        except OSError:
            pass
        # o catálogo muda (itens instalados)
        for it in ok:
            it.installed = True
        if getattr(self, "close_after", False):
            self.close()

    def on_retry(self, _b):
        bad = [i for i in self.queue if i.state != "ok"]
        self.start_install(bad)

    def back_to_main(self):
        # recarrega o catálogo para refletir o que foi instalado
        self.groups = []
        for name in ("main", "progress"):
            ch = self.pages.get_child_by_name(name)
            if ch:
                self.pages.remove(ch)
        self.pages.set_visible_child_name("load")
        threading.Thread(target=self.load_catalog, daemon=True).start()

    def open_log(self):
        if os.path.exists(LOG):
            Gio.AppInfo.launch_default_for_uri(GLib.filename_to_uri(LOG), None)
        else:
            self.toast.add_toast(Adw.Toast(title="Ainda não há log."))


class App(Adw.Application):
    def __init__(self, backend, dry):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.backend, self.dry = backend, dry

    def do_startup(self):
        Adw.Application.do_startup(self)
        Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.FORCE_DARK)
        css = Gtk.CssProvider()
        if hasattr(css, "load_from_string"):
            css.load_from_string(CSS)
        else:
            css.load_from_data(CSS.encode())
        disp = Gdk.Display.get_default()
        Gtk.StyleContext.add_provider_for_display(disp, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        theme = Gtk.IconTheme.get_for_display(disp)
        for d in ("/var/lib/flatpak/exports/share/icons",
                  os.path.expanduser("~/.local/share/flatpak/exports/share/icons")):
            if os.path.isdir(d) and d not in theme.get_search_path():
                theme.add_search_path(d)
        self.set_accels_for_action("win.log", ["<Ctrl>l"])

    def do_activate(self):
        Win(self, self.backend, self.dry).present()


def main():
    args = sys.argv[1:]
    backend = os.path.join(HERE, "install-apps.sh")
    if "--backend" in args:
        backend = args[args.index("--backend") + 1]
    dry = "--dry-run" in args
    GLib.set_prgname("viskooos-apps")
    GLib.set_application_name(TITLE)
    App(backend, dry).run([sys.argv[0]])


if __name__ == "__main__":
    main()
