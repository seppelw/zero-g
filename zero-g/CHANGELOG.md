# Changelog

## 1.1.1

- 🐛 **Fix**: Verbindungs-Health-Check im Ingress Dashboard angepasst: Nginx pollt nun den nativen `/healthz` Endpunkt der Antigravity-CLI. Sobald der Daemon online ist, schaltet die Status-Ampel im Dashboard sofort auf Grün (`Online als "homeassistant-zero-g"`).

## 1.1.0

- 🐛 **Fix**: Das Home Assistant Ingress UI ("Web UI öffnen") gibt nun keinen `404 page not found` Fehler mehr aus, nachdem die Authentifizierung abgeschlossen ist. Da die Antigravity-CLI kein lokales Frontend ausliefert, sondern als Remote-Control-Daemon fungiert, dient das Ingress-Fenster nun als persistentes Zero-G Dashboard mit klaren Anweisungen und einem Link zur offiziellen Web-Oberfläche (`antigravity.google`).

## 1.0.9

- 🐛 **Fix**: Behebt den `client_secret is missing` Fehler bei der Token-Einlösung. Das Add-on injiziert nun das korrekte Client-Secret der Antigravity-CLI in den OAuth-Exchange-Request, wodurch Google den Token erfolgreich ausstellt.

## 1.0.8

- 🐛 **Fix**: Das Einlösen von Google OAuth Codes (PKCE) wurde komplett neugeschrieben. Das Add-on generiert nun den Authentifizierungslink und den dazugehörigen PKCE-Code selbstständig und löst deinen Code im Hintergrund ein, da die CLI bei Neustarts den erforderlichen Challenge-State vergisst. Das Add-on wartet nun brav, bis ein gültiger Token existiert, bevor die CLI gestartet wird.

## 1.0.7

- 🐛 **Fix**: Umgebungsvariablen-Injektion für s6-overlay v3 repariert. Das Skript re-exekutiert sich nun mit `with-contenv`, sodass der `SUPERVISOR_TOKEN` verfügbar ist und API-Fehler (403 Forbidden) komplett behoben sind.
- 🐛 **Fix**: Der Dummy-Befehl zum Einlösen von Google OAuth Codes wurde korrigiert, da die CLI kein dediziertes `auth login` Subkommando besitzt.

## 1.0.6

- ✨ **Neu**: Das Add-on erkennt nun automatisch, wenn ein Google OAuth "Authorization Code" (beginnend mit `4/`) in das `auth_token`-Feld eingetragen wird, und tauscht diesen im Hintergrund über `agy auth login` gegen ein echtes Access-Token aus. Dies behebt das Problem, dass die CLI im Hintergrund auf eine Code-Eingabe gewartet hat und dadurch Ingress mit einem 404-Fehler fehlschlug.

## 1.0.5

- 🐛 **Fix**: Fehlende Berechtigung (`hassio_api: true`) in der Konfiguration hinzugefügt. Das Add-on darf nun wieder die eigenen Einstellungen (inklusive `auth_token` und MCP-Settings) über die Supervisor-API auslesen (behebt `Unable to access the API, forbidden`).

## 1.0.4

- 🐛 **Fix**: Umgebungsvariable `HOME` wird nun explizit auf `/root` gesetzt. Behebt einen Fehler (`$HOME is not defined`), bei dem die Antigravity CLI in manchen Home Assistant Installationen nicht starten konnte, da die s6-Umgebung `HOME` nicht automatisch exportiert hat.

## 1.0.3

- 🛡️ **Neu**: Präventiver Hardware-Kompatibilitätscheck (PCLMULQDQ CPU-Flag) hinzugefügt. Das Add-on beendet sich nun mit einer klaren Fehler- und Lösungsbeschreibung (z.B. Umstellung des VM CPU Typs in Proxmox auf "host"), anstatt in einer Boot-Schleife (`sigill-fail-fast`) hängen zu bleiben.

## 1.0.2

- 🐛 **Fix**: Supervisor Validierungsfehler (`Ungültige Konfiguration - expected a URL`) beim Add-on Start behoben, indem das Schema für optionale URLs von `url?` auf `str?` geändert wurde.

## 1.0.1

- 🐛 **Fix**: Dockerfile Build-Konflikt behoben (redundante Bashio-Installation entfernt).

## 1.0.0 (Initial Release: Zero-G)

- 🛸 **Zero-G Launch**: Schwerelose KI-Entwicklung und Smart-Home-Orchestrierung für Home Assistant powered by Google Antigravity.
- ✨ **Automatischer Download & Updates**: Lädt automatisch die neueste offizielle Antigravity Version von Google herunter (Multi-Arch: `amd64` und `aarch64`).
- 🌐 **Home Assistant Ingress**: Nahtlose Einbettung des vollständigen Webinterfaces in die Home Assistant Seitenleiste über integrierten Nginx Reverse Proxy.
- 🔌 **Home Assistant MCP Server Integration**:
  - Automatische 1-Klick-Konfiguration über Home Assistant Supervisor (`http://supervisor/core/api/mcp`).
  - Unterstützung für manuelle URLs und Long-Lived Access Tokens.
  - Optionale Unterstützung für den Home Assistant History MCP Server (`hass_mcp`).
- 🚀 **Geführtes Onboarding**:
  - Responsive Status- und Onboarding-Weboberfläche für Ersteinrichtung mit automatischem Health-Check.
  - Ausgabe der Sign-In URL im Add-on Log.
- 🔒 **Persistente Datenspeicherung**: Sichere Speicherung aller Tokens, Einstellungen und Sitzungen im `/data`-Volume.
- 📂 **Voller Zugriff auf `/config`**: Zero-G kann Home Assistant Automationen, Scripts und Konfigurationen direkt einsehen und bearbeiten.
