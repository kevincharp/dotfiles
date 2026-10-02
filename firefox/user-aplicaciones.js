// --- ESPEJO DE INTERFAZ (copiado de Personal; Aplicaciones no se usa para navegar) ---
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"ublock0_raymondhill_net-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"back-button\",\"forward-button\",\"stop-reload-button\",\"vertical-spacer\",\"urlbar-container\",\"78272b6fa58f4a1abaac99321d503a20_proton_me-browser-action\",\"unified-extensions-button\",\"downloads-button\",\"screenshot-button\",\"ipprotection-button\",\"fxa-toolbar-menu-button\",\"reset-pbm-toolbar-button\",\"preferences-button\",\"alltabs-button\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[],\"vertical-tabs\":[\"tabbrowser-tabs\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"reset-pbm-toolbar-button\",\"developer-button\",\"screenshot-button\",\"78272b6fa58f4a1abaac99321d503a20_proton_me-browser-action\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\",\"ipprotection-button\",\"ublock0_raymondhill_net-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"vertical-tabs\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\",\"PersonalToolbar\"],\"currentVersion\":26,\"newElementCount\":6}");
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.tabs.inTitlebar", 1);
user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");
user_pref("browser.newtabpage.enabled", false);

// --- Aplicaciones: NO borrar cookies ni storage al cerrar ---
// Este perfil solo guarda sesiones de PWA (Teams, Outlook...). Con el borrado activo se perdian
// hasta los sitios con excepcion "Permitir" (ESTSAUTHPERSISTENT incluido) y habia que loguearse
// en cada apertura. El historial y la cache se siguen borrando.
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", false);
