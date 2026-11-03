// ViskooOS — Zen Browser (aplicado pelo ViskooOS Apps)
// tema cinza chumbo da interface (chrome/userChrome.css); as páginas dos sites não são alteradas
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.theme.toolbar-theme", 0);
// barra de endereços fixa no topo; só a barra lateral de abas se esconde (aparece na borda esquerda)
user_pref("zen.view.use-single-toolbar", false);
user_pref("zen.view.compact.hide-toolbar", false);
user_pref("zen.view.compact.hide-tabbar", true);
user_pref("zen.view.compact.enable-at-startup", true);
