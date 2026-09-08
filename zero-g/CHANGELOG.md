# Changelog

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
