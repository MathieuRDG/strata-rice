// Strata — préférences Firefox (réappliquées à chaque démarrage)
// Barre de titre du système : la décoration Aurorae Strata remplace celle de Firefox
user_pref("browser.tabs.inTitlebar", 0);
// Autorise chrome/userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Interface et pages en sombre
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
// Densité compacte (barres plus fines, proches des barres de titre Strata)
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);
