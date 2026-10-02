// user.js - privacidad (comun a los perfiles Personal y Aplicaciones)
// Se reaplica en cada arranque: lo que se cambie desde Ajustes vuelve a este valor.

// --- Antirrastreo ---
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.globalprivacycontrol.enabled", true);

// --- DNS sobre HTTPS (Cloudflare), con respaldo al DNS del sistema ---
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
user_pref("network.trr.excluded-domains", "");   // pendiente: dominios internos de la VPN

// --- Telemetria y estudios ---
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);

// --- Barra de direcciones: sin sugerencias de buscador ni atajos ---
// Las sugerencias mandan lo que se tipea al buscador antes de buscar.
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.showSearchSuggestionsFirst", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.urlbar.suggest.topsites", false);   // atajos al enfocar la barra (p. ej. la pagina de inicio de Fedora)

// --- Otros ajustes que estaban solo en Personal (espejo) ---
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", false);   // sin lista de "conveniencia" en ETP estricto
user_pref("general.autoScroll", true);

// --- Contenido patrocinado ---
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);

// --- IA ---
user_pref("browser.ml.enable", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);

// --- Gestor de contrasenas y autocompletado de Firefox (se usa Proton) ---
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("signon.generation.enabled", false);
user_pref("signon.management.page.breach-alerts.enabled", false);
user_pref("signon.firefoxRelay.feature", "disabled");
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// --- Borrado al cerrar (las excepciones de cookies "Permitir" se conservan) ---
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("privacy.clearOnShutdown_v2.siteSettings", false);   // conservar permisos y excepciones

// --- IA: bloqueo general (equivale al interruptor "Bloquear mejoras de IA" de Ajustes) ---
// Para habilitar algo (p. ej. traducciones locales): quitar estas lineas en AMBOS perfiles.
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.translations.enable", false);
user_pref("browser.smartwindow.memories.generateFromConversation", false);
user_pref("browser.smartwindow.memories.generateFromHistory", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.ml.chat.page", false);
