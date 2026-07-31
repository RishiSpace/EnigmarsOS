// EnigmaOS Firefox privacy defaults
// No telemetry, HTTPS-only, DoH, strong tracking protection.

// --- Telemetry / data reporting OFF ---
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.sessions.current.clean", true);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// --- HTTPS-Only Mode ---
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_ever_enabled", true);

// --- DNS over HTTPS (Cloudflare as default resolver; user-changeable) ---
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
user_pref("network.trr.bootstrapAddress", "1.1.1.1");

// --- Tracking protection ---
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("network.cookie.cookieBehavior", 5);
user_pref("network.http.referer.XOriginTrimmingPolicy", 2);

// --- First-party isolation / containers friendly ---
user_pref("privacy.firstparty.isolate", false);
user_pref("browser.contentblocking.category", "strict");

// --- Disable pocket / sponsored content ---
user_pref("extensions.pocket.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
user_pref("browser.newtabpage.activity-stream.default.sites", "");
user_pref("browser.topsites.contile.enabled", false);

// --- Safe defaults ---
user_pref("browser.formfill.enable", false);
user_pref("signon.rememberSignons", true);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("geo.enabled", false);
user_pref("beacon.enabled", false);
user_pref("dom.battery.enabled", false);

// --- Branding-ish homepage ---
user_pref("browser.startup.homepage", "https://enigmaos.rishispace.dev");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_override_url", "");
